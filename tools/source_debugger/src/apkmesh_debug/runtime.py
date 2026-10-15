from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import quickjs

from .host import SourceHost, as_json_value
from .models import SourceManifest, SourceHostError
from .trace import TraceRecorder


_BOOTSTRAP = r"""
globalThis.apkmesh = {
  request: async (url, options = {}) => {
    const response = await sendMessage('apkmesh.request', JSON.stringify({
      url,
      headers: options.headers || {},
      method: options.method || 'GET',
      body: options.body === undefined ? null : String(options.body),
    }));
    if (response && typeof response === 'object' && response.__apkmeshRequestError) {
      throw new Error(response.__apkmeshRequestError);
    }
    return response;
  },
  browser: {
    open: async (url) => {
      const tabId = await sendMessage(
        'apkmesh.browser.open',
        JSON.stringify({url})
      );
      return {
        id: tabId,
        waitFor: (selector) => sendMessage(
          'apkmesh.browser.waitFor',
          JSON.stringify({tabId, selector})
        ),
        waitForUrlChange: (previousUrl) => sendMessage(
          'apkmesh.browser.waitForUrlChange',
          JSON.stringify({tabId, previousUrl})
        ),
        query: (selectors) => sendMessage(
          'apkmesh.browser.query',
          JSON.stringify({tabId, selectors})
        ),
        queryAll: (rootSelector, selectors) => sendMessage(
          'apkmesh.browser.queryAll',
          JSON.stringify({tabId, rootSelector, selectors})
        ),
        close: () => sendMessage(
          'apkmesh.browser.close',
          JSON.stringify({tabId})
        ),
      };
    },
  },
  download: (url, options = {}) => sendMessage(
    'apkmesh.download',
    JSON.stringify({url, fileName: options.fileName, headers: options.headers || {}})
  ),
  install: (filePath) => sendMessage(
    'apkmesh.install',
    JSON.stringify({filePath})
  ),
  detailProgress: (requestId, update) => sendMessage(
    'apkmesh.detailProgress',
    JSON.stringify({requestId, update})
  ),
};
"""


class SourceRuntime:
    def __init__(
        self,
        script_path: Path,
        host: SourceHost | None,
        trace: TraceRecorder,
        *,
        timeout: float = 30.0,
    ) -> None:
        self.script_path = script_path
        self.host = host
        self.trace = trace
        self.timeout = timeout
        self.context = quickjs.Context()
        self.context.set_memory_limit(64 * 1024 * 1024)
        self.context.set_max_stack_size(2 * 1024 * 1024)
        self._disposed = False
        self.context.add_callable("sendMessage", self._send_message)
        self.context.eval(_BOOTSTRAP)
        self.context.eval(script_path.read_text(encoding="utf-8"))
        self.manifest = SourceManifest.from_raw(self._eval_json("JSON.stringify(source.manifest)"))
        self.trace.add(
            "source.loaded",
            path=script_path,
            source_id=self.manifest.source_id,
            name=self.manifest.name,
        )

    def attach_host(self, host: SourceHost) -> None:
        if self._disposed:
            raise RuntimeError("source runtime has been disposed")
        self.host = host

    def has_method(self, method: str) -> bool:
        if self._disposed:
            raise RuntimeError("source runtime has been disposed")
        method_json = json.dumps(method)
        return bool(self.context.eval(f"typeof source[{method_json}] === 'function'"))

    def call(self, method: str, *arguments: Any) -> Any:
        if self._disposed:
            raise RuntimeError("source runtime has been disposed")
        if self.host is None:
            raise RuntimeError("source host has not been attached")
        self.trace.add(
            "source.call",
            method=method,
            arguments=list(arguments),
        )
        encoded_arguments = ", ".join(
            json.dumps(argument, ensure_ascii=False) for argument in arguments
        )
        method_json = json.dumps(method)
        job = f"""
          globalThis.__apkmesh_done = false;
          globalThis.__apkmesh_result = null;
          globalThis.__apkmesh_error = null;
          (async () => {{
            try {{
              if (typeof source[{method_json}] !== 'function') {{
                throw new Error('source method is not defined: ' + {method_json});
              }}
              globalThis.__apkmesh_result = await source[{method_json}]({encoded_arguments});
            }} catch (error) {{
              globalThis.__apkmesh_error = String(error) + (error && error.stack ? '\\n' + error.stack : '');
            }} finally {{
              globalThis.__apkmesh_done = true;
            }}
          }})();
        """
        self.context.eval(job)
        deadline = time.monotonic() + self.timeout
        while True:
            if self.context.eval("globalThis.__apkmesh_done === true"):
                break
            if time.monotonic() >= deadline:
                raise TimeoutError(f"source call timed out: {method}")
            self.context.execute_pending_job()
            time.sleep(0.001)

        error = self.context.eval("globalThis.__apkmesh_error")
        if error:
            self.trace.add("source.error", method=method, error=str(error))
            raise SourceHostError(str(error))
        result = self._eval_json("JSON.stringify(globalThis.__apkmesh_result)")
        self.trace.add("source.completed", method=method, result=result)
        return result

    def close(self) -> None:
        self._disposed = True
        self.context.gc()

    def _send_message(self, name: str, payload: str) -> Any:
        if self.host is None:
            raise RuntimeError("source host has not been attached")
        try:
            value = json.loads(payload) if isinstance(payload, str) else payload
            if not isinstance(value, dict):
                value = {}
            result = self.host.dispatch(name, value)
            return as_json_value(result, self.context.parse_json)
        except Exception as error:
            self.trace.add("host.error", message=name, error=str(error))
            if name == "apkmesh.request":
                return self.context.parse_json(json.dumps({"__apkmeshRequestError": str(error)}))
            raise

    def _eval_json(self, expression: str) -> Any:
        value = self.context.eval(expression)
        if not isinstance(value, str):
            raise ValueError(f"expected JSON string from QuickJS: {expression}")
        if value == "undefined":
            return None
        return json.loads(value)
