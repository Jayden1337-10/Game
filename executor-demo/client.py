import json
import threading
import time
import urllib.request
import urllib.error
import tkinter as tk
from tkinter import ttk, messagebox

class ExecutorDemo:
    def __init__(self, root):
        self.root=root
        self.root.title("FW Executor | Forgotten World")
        self.root.geometry("520x430")
        self.root.resizable(False,False)
        self.token=None
        self.session_id=None
        self.ends_at=0
        self.running=False
        root.configure(bg="#11151c")
        tk.Label(root,text="FW EXECUTOR",font=("Segoe UI",24,"bold"),fg="#f04b55",bg="#11151c").pack(pady=(22,2))
        tk.Label(root,text="Forgotten World compatibility tool",font=("Segoe UI",10),fg="#aab4c2",bg="#11151c").pack()
        tk.Label(root,text="DEMO CLIENT • signs in to your Forgotten World account",font=("Segoe UI",9,"bold"),fg="#e2b86b",bg="#11151c").pack(pady=12)
        panel=tk.Frame(root,bg="#1b222d",padx=18,pady=16); panel.pack(fill="x",padx=24)
        self.server=self.field(panel,"Server URL","https://your-wispbyte-host.example")
        self.username=self.field(panel,"Game username","")
        self.password=self.field(panel,"Game password","",show="*")
        self.status=tk.Label(root,text="Ready. Use a disposable test account.",fg="#d2dae4",bg="#11151c",wraplength=460)
        self.status.pack(pady=18)
        self.timer=tk.Label(root,text="03:00",font=("Consolas",25,"bold"),fg="#f04b55",bg="#11151c")
        self.timer.pack()
        self.button=tk.Button(root,text="INJECT / START DEMO",command=self.start,bg="#b93643",fg="white",activebackground="#d14a56",relief="flat",font=("Segoe UI",11,"bold"),padx=18,pady=10)
        self.button.pack(pady=18)
        tk.Label(root,text="This demo only affects the game account you sign into. It does not modify Windows or Discord.",font=("Segoe UI",8),fg="#7f8b9b",bg="#11151c",wraplength=470).pack(pady=4)

    def field(self,parent,label,default,show=None):
        tk.Label(parent,text=label,fg="#cbd5e1",bg="#1b222d",anchor="w").pack(fill="x")
        entry=tk.Entry(parent,show=show,bg="#0f141b",fg="white",insertbackground="white",relief="flat")
        entry.pack(fill="x",pady=(4,10),ipady=7)
        entry.insert(0,default)
        return entry

    def request(self,path,data,token=None):
        body=json.dumps(data).encode()
        req=urllib.request.Request(self.base_url+"/api/"+path,data=body,headers={"Content-Type":"application/json"})
        if token: req.add_header("Authorization","Bearer "+token)
        try:
            with urllib.request.urlopen(req,timeout=12) as response:
                return json.loads(response.read().decode())
        except urllib.error.HTTPError as exc:
            try: detail=json.loads(exc.read().decode())
            except Exception: detail={"error":str(exc)}
            raise RuntimeError(detail.get("error","HTTP "+str(exc.code)))

    def start(self):
        if self.running:return
        self.base_url=self.server.get().strip().rstrip("/")
        self.login_name=self.username.get().strip()
        self.login_password=self.password.get()
        if not self.base_url.startswith(("http://","https://")):
            self.failed("Enter a valid http:// or https:// server URL")
            return
        self.button.config(state="disabled")
        self.status.config(text="Connecting to Forgotten World...")
        threading.Thread(target=self._begin,daemon=True).start()

    def _begin(self):
        try:
            auth=self.request("login",{"username":self.login_name,"password":self.login_password})
            token=auth["token"]
            result=self.request("demo-exploit/start",{},token)
            self.token=token
            self.session_id=result["session_id"]
            self.ends_at=time.time()+int(result.get("wait_seconds",180))
            self.running=True
            self.root.after(0,lambda:self.status.config(text="Injection simulated. Detection window active..."))
            self.root.after(0,self.tick)
        except Exception as exc:
            self.root.after(0,lambda message=str(exc):self.failed(message))

    def failed(self,message):
        self.status.config(text="Connection failed: "+message)
        self.button.config(state="normal")

    def tick(self):
        if not self.running:return
        remaining=max(0,int(self.ends_at-time.time()))
        self.timer.config(text="%02d:%02d"%(remaining//60,remaining%60))
        if remaining:
            self.root.after(250,self.tick)
        else:
            self.status.config(text="Exploit detected. Applying account sanction...")
            threading.Thread(target=self._finish,daemon=True).start()

    def _finish(self):
        try:
            result=self.request("demo-exploit/finish",{"session_id":self.session_id},self.token)
            self.root.after(0,lambda:self.banned(result.get("message","HAHA GET BANNED BUDDY")))
        except Exception as exc:
            self.root.after(0,lambda:self.failed(str(exc)))

    def banned(self,message):
        self.running=False
        self.status.config(text=message,fg="#ff5964")
        self.timer.config(text="BANNED")
        self.button.config(text="DEMO COMPLETE",state="disabled")
        messagebox.showwarning("Forgotten World", "HAHA GET BANNED BUDDY\n\nYour Forgotten World test account has been banned.")

if __name__=="__main__":
    root=tk.Tk()
    ExecutorDemo(root)
    root.mainloop()
