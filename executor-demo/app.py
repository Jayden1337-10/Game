import json
import random
import threading
import time
import tkinter as tk
from tkinter import messagebox
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

APP_TITLE = "FORGOTTEN WORLD // EXECUTOR DEMO"
DURATION = 15 * 60

class DemoApp:
    def __init__(self, root):
        self.root = root
        self.root.title(APP_TITLE)
        self.root.geometry("760x560")
        self.root.minsize(700, 500)
        self.root.configure(bg="#0b0e12")
        self.token = ""
        self.session_id = ""
        self.deadline = 0
        self.running = False
        self.last_log = 0
        self._build_login()

    def api(self, path, method="GET", payload=None, authenticated=True):
        base = self.server.get().strip().rstrip("/")
        if not base.startswith(("http://", "https://")):
            raise ValueError("Server URL must begin with http:// or https://")
        headers = {"Content-Type": "application/json"}
        if authenticated and self.token:
            headers["Authorization"] = "Bearer " + self.token
        data = json.dumps(payload or {}).encode("utf-8") if method != "GET" else None
        req = Request(base + path, data=data, headers=headers, method=method)
        try:
            with urlopen(req, timeout=15) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            try:
                detail = json.loads(exc.read().decode("utf-8"))
            except Exception:
                detail = {"error": str(exc)}
            raise RuntimeError(detail.get("error", "Server request failed"))
        except URLError as exc:
            raise RuntimeError("Could not reach the Forgotten World server: " + str(exc.reason))

    def _label(self, parent, value, size=10, color="#aab6c5"):
        return tk.Label(parent, text=value, bg=parent.cget("bg"), fg=color,
                        font=("Consolas", size), anchor="w")

    def _build_login(self):
        shell = tk.Frame(self.root, bg="#10161e", padx=28, pady=24)
        shell.pack(fill="both", expand=True, padx=22, pady=22)
        self._label(shell, "FORGOTTEN WORLD", 18, "#e7edf5").pack(anchor="w")
        self._label(shell, "EXECUTOR SIMULATOR  //  OPT-IN DEMO", 10, "#6de0a3").pack(anchor="w", pady=(2, 18))
        self._label(shell, "This is a harmless visual simulation. It does not inject into games, run scripts, or modify other software.", 10).pack(anchor="w", pady=(0, 18))
        self.server = tk.Entry(shell, bg="#080b10", fg="#dce6f2", insertbackground="white", relief="flat")
        self.server.insert(0, "https://YOUR-WISPBYTE-URL")
        self.server.pack(fill="x", ipady=9, pady=5)
        self.username = tk.Entry(shell, bg="#080b10", fg="#dce6f2", insertbackground="white", relief="flat")
        self.username.insert(0, "")
        self.username.pack(fill="x", ipady=9, pady=5)
        self.password = tk.Entry(shell, bg="#080b10", fg="#dce6f2", insertbackground="white", relief="flat", show="•")
        self.password.pack(fill="x", ipady=9, pady=5)
        self.confirmed = tk.BooleanVar(value=False)
        tk.Checkbutton(shell, text="I understand this starts a 15-minute demo and applies a reversible test ban to this Forgotten World account.", variable=self.confirmed, bg="#10161e", fg="#cbd5e1", selectcolor="#080b10", activebackground="#10161e", activeforeground="white", wraplength=640, justify="left").pack(anchor="w", pady=16)
        tk.Button(shell, text="SIGN IN & START DEMO", command=self.start_demo, bg="#1e6b4d", fg="white", activebackground="#2a8b65", relief="flat", padx=18, pady=12).pack(anchor="w")
        self.login_status = self._label(shell, "The timer starts after successful sign-in and confirmation.", 9, "#77879a")
        self.login_status.pack(anchor="w", pady=14)

    def start_demo(self):
        if not self.confirmed.get():
            messagebox.showwarning("Confirmation required", "Confirm that you understand this is a demo test ban.")
            return
        username = self.username.get().strip()
        password = self.password.get()
        if not username or not password:
            messagebox.showwarning("Sign in", "Enter your Forgotten World username and password.")
            return
        try:
            login = self.api("/api/login", "POST", {"username": username, "password": password}, authenticated=False)
            self.token = login["token"]
            session = self.api("/api/demo-exploit/start", "POST", {"confirmed": True})
            self.session_id = session["session_id"]
            self.deadline = time.time() + int(session.get("wait_seconds", DURATION))
            self._build_console()
            self.running = True
            self._log("Authenticated as " + username)
            self._log("Demo session registered with Forgotten World server")
            self._log("No external processes or game memory will be accessed")
            self.tick()
        except Exception as exc:
            self.login_status.config(text=str(exc), fg="#ff8585")

    def _build_console(self):
        for child in self.root.winfo_children():
            child.destroy()
        self.root.configure(bg="#0b0e12")
        top = tk.Frame(self.root, bg="#10161e", padx=18, pady=12)
        top.pack(fill="x", padx=14, pady=(14, 6))
        self._label(top, "FW EXECUTOR  /  SIMULATION MODE", 14, "#e7edf5").pack(side="left")
        self.timer = self._label(top, "15:00", 16, "#6de0a3")
        self.timer.pack(side="right")
        body = tk.Frame(self.root, bg="#10161e", padx=14, pady=14)
        body.pack(fill="both", expand=True, padx=14, pady=6)
        self._label(body, "OUTPUT CONSOLE", 9, "#6de0a3").pack(anchor="w")
        self.console = tk.Text(body, bg="#070a0e", fg="#9db6a8", insertbackground="white", relief="flat", font=("Consolas", 9), height=18, state="disabled")
        self.console.pack(fill="both", expand=True, pady=(8, 12))
        controls = tk.Frame(body, bg="#10161e")
        controls.pack(fill="x")
        for caption, callback in [
            ("INJECT", lambda: self._fake_action("Injector attached (visual simulation only)")),
            ("EXECUTE", lambda: self._fake_action("Demo script executed locally (no code was run)")),
            ("GIVE ITEMS", lambda: self._fake_action("Preview items added to the fake console inventory")),
        ]:
            tk.Button(controls, text=caption, command=callback, bg="#202d3b", fg="#dce6f2", activebackground="#34495e", relief="flat", padx=16, pady=8).pack(side="left", padx=(0, 8))
        self._label(body, "DEMO ONLY • No real exploit functionality • Test ban is reversible by the game administrator", 8, "#d6aa62").pack(anchor="w", pady=(12, 0))

    def _log(self, line):
        if not hasattr(self, "console"):
            return
        stamp = time.strftime("%H:%M:%S")
        self.console.configure(state="normal")
        self.console.insert("end", f"[{stamp}] {line}\n")
        self.console.see("end")
        self.console.configure(state="disabled")

    def _fake_action(self, line):
        if self.running:
            self._log(line)

    def tick(self):
        if not self.running:
            return
        remaining = max(0, int(self.deadline - time.time()))
        self.timer.config(text=f"{remaining // 60:02d}:{remaining % 60:02d}")
        now = time.time()
        if now - self.last_log > 5:
            self.last_log = now
            self._log(random.choice([
                "Scanning demo environment...",
                "Resolving fake item catalogue...",
                "Synchronizing cosmetic preview...",
                "Checking simulated session integrity...",
                "Waiting for demo timer...",
                "No external process handles opened.",
            ]))
        if remaining <= 0:
            self.finish_demo()
            return
        self.root.after(1000, self.tick)

    def finish_demo(self):
        self.running = False
        try:
            result = self.api("/api/demo-exploit/finish", "POST", {"session_id": self.session_id})
            self._log(result.get("message", "DEMO COMPLETE"))
            self._log("A reversible test-ban flag was applied to this Forgotten World account.")
            messagebox.showinfo("Demo complete", "HAHA GET BANNED BUDDY\n\nA reversible demo test ban was applied. The game administrator can clear it.")
        except Exception as exc:
            self._log("Server could not confirm demo completion: " + str(exc))
            messagebox.showerror("Could not finish demo", str(exc))

if __name__ == "__main__":
    root = tk.Tk()
    DemoApp(root)
    root.mainloop()
