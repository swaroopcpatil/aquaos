import json
import logging


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        data = {"ts": self.formatTime(record), "level": record.levelname,
                "logger": record.name, "message": record.getMessage()}
        extra = getattr(record, "ctx", None)
        if isinstance(extra, dict):
            data.update(extra)
        if record.exc_info:
            data["exc"] = self.formatException(record.exc_info)  # server logs only
        return json.dumps(data, default=str)


def setup_logging(level: int = logging.INFO) -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)
