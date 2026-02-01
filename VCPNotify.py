import websocket
import json
import threading
import time
import platform
import subprocess
import os

# --- Configuration ---
VCP_KEY = os.environ.get('VCP_KEY', '123456')
WS_SERVER_URL = os.environ.get('WS_SERVER_URL', 'ws://localhost:5890')
WS_URL = f"{WS_SERVER_URL}/VCPlog/VCP_Key={VCP_KEY}"

def show_notification(title, message):
    system = platform.system()
    print(f"[{system}] Notification: {title} - {message}")
    
    try:
        if system == "Windows":
            from win10toast import ToastNotifier
            notifier = ToastNotifier()
            notifier.show_toast(title, message, duration=5, threaded=True)
        elif system == "Darwin":  # macOS
            # Use AppleScript for native macOS notifications
            # Escape double quotes in message and title
            safe_message = message.replace('"', '\\"')
            safe_title = title.replace('"', '\\"')
            script = f'display notification "{safe_message}" with title "{safe_title}"'
            subprocess.run(["osascript", "-e", script])
        elif system == "Linux":
            subprocess.run(["notify-send", title, message])
    except Exception as e:
        print(f"Failed to show notification: {e}")

def on_message(ws_app, message):
    try:
        data = json.loads(message)
        if data.get('type') == 'vcp_log' and data.get('data'):
            log_data = data['data']
            
            # If log_data is a string, try to parse it as JSON
            if isinstance(log_data, str):
                try:
                    log_data = json.loads(log_data)
                except json.JSONDecodeError:
                    pass
            
            title = "VCP Notification"
            content = ""
            
            if isinstance(log_data, dict):
                # Handle agent_message type
                if log_data.get('type') == 'agent_message' and 'message' in log_data:
                    content = log_data['message']
                    if 'title' in log_data:
                        title = log_data['title']
                # Handle standard title/content
                elif 'content' in log_data:
                    title = log_data.get('title', title)
                    content = log_data['content']
                else:
                    content = json.dumps(log_data, ensure_ascii=False, indent=2)
            else:
                content = str(log_data)
            
            if len(content) > 200:
                content = content[:197] + "..."
            show_notification(title, content)
    except Exception as e:
        print(f"Error processing message: {e}")

def on_error(ws_app, error):
    print(f"WebSocket Error: {error}")

def on_close(ws_app, close_status_code, close_msg):
    print("WebSocket Closed. Reconnecting in 5s...")
    time.sleep(5)
    start_websocket_client()

def on_open(ws_app):
    print("WebSocket Connected!")
    show_notification("VCP", "Notification listener connected!")

def start_websocket_client():
    ws_app = websocket.WebSocketApp(
        WS_URL,
        on_open=on_open,
        on_message=on_message,
        on_error=on_error,
        on_close=on_close
    )
    ws_app.run_forever(ping_interval=10, ping_timeout=5)

if __name__ == "__main__":
    start_websocket_client()
