"""برنامج إنشاء فرع جديد: ينشئ تطبيق (اختصار سطح مكتب) لفرع جديد.

خطوات الاستخدام:
1) أنشئ الفرع الجديد أولاً من النظام الأساسي (قسم «إضافة فرع»).
2) افتح هذا البرنامج وأدخل اسم الفرع ومعرفه (branch6 مثلاً).
3) اضغط «إنشاء التطبيق على سطح المكتب» — تظهر أيقونة تفتح الفرع
   كتطبيق مستقل في Chrome عبر الرابط السحابي.
"""
import json
import os
import re
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox

HOST = 'https://accountingsystem-fc3f0.web.app'

CHROME_CANDIDATES = [
    os.path.expandvars(r'%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe'),
    os.path.join(os.environ.get('ProgramFiles', ''), 'Google',
                 'Chrome', 'Application', 'chrome.exe'),
    os.path.join(os.environ.get('ProgramFiles(x86)', ''),
                 'Google', 'Chrome', 'Application', 'chrome.exe'),
]

EDGE_CANDIDATES = [
    os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\Edge\Application\msedge.exe'),
    os.path.join(os.environ.get('ProgramFiles', ''), 'Microsoft',
                 'Edge', 'Application', 'msedge.exe'),
]

AMBER = '#B45309'
AMBER_BG = '#0F172A'
FIELD_BG = '#F8FAFC'
WHITE = '#FFFFFF'


def _safe_name(text):
    return re.sub(r'[\\/:*?"<>|]+', '_', str(text)).strip() or 'نظام جديد'


def _desktop_path():
    try:
        out = subprocess.check_output(
            ['powershell', '-NoProfile', '-Command',
             "[Environment]::GetFolderPath('Desktop')"],
            text=True,
        )
        path = out.strip()
        if path and os.path.isdir(path):
            return path
    except Exception:
        pass
    fallback = os.path.join(os.path.expanduser('~'), 'Desktop')
    return fallback if os.path.isdir(fallback) else os.path.expanduser('~')


def _find_browser():
    for path in CHROME_CANDIDATES + EDGE_CANDIDATES:
        if path and os.path.isfile(path):
            return path
    try:
        out = subprocess.check_output(
            ['where', 'chrome'], shell=True, text=True,
            stderr=subprocess.STDOUT,
        )
        return out.strip().splitlines()[0].strip()
    except Exception:
        return None


def _create_lnk(path, browser, url, description):
    args = f'--app={url} --new-window'
    ps_script = (
        "$s=(New-Object -ComObject WScript.Shell).CreateShortcut("
        + json.dumps(path, ensure_ascii=False)
        + ");"
        + "$s.TargetPath=" + json.dumps(browser, ensure_ascii=False) + ';'
        + "$s.Arguments=" + json.dumps(args, ensure_ascii=False) + ';'
        + "$s.Description=" + json.dumps(description, ensure_ascii=False) + ';'
        + "$s.IconLocation=" + json.dumps(browser + ',0', ensure_ascii=False) + ';'
        + "$s.Save();"
    )
    subprocess.run(
        ['powershell', '-NoProfile', '-Command', ps_script],
        check=True, timeout=60,
    )


def _create_url_file(path, url):
    content = '[InternetShortcut]\r\nURL=' + url + '\r\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)


class BranchProgramApp:
    def __init__(self, root):
        self.root = root
        root.title('برنامج إنشاء فرع جديد — النظام المحاسبي')
        root.geometry('620x620')
        root.minsize(560, 560)
        root.configure(bg=WHITE)
        try:
            root.tk.call('tk', 'scaling', 1.2)
        except Exception:
            pass

        self.name_var = tk.StringVar(value='فرع ')
        self.code_var = tk.StringVar(value='BR06')
        self.sys_var = tk.StringVar(value='branch6')
        self.user_var = tk.StringVar(value='ad6')
        self.pass_var = tk.StringVar(value='1254')
        self.url_var = tk.StringVar()

        self._build_header()
        self._build_form()
        self._build_footer()
        self._update_url()

    # ============ البناء ============
    def _build_header(self):
        header = tk.Frame(self.root, bg=AMBER_BG)
        header.pack(fill='x')
        tk.Label(
            header, text='إنشاء تطبيق فرع جديد', fg=WHITE, bg=AMBER_BG,
            font=('Segoe UI', 17, 'bold'),
        ).pack(pady=(16, 2))
        tk.Label(
            header, text='أدخل بيانات الفرع ثم أنشئ تطبيقه على سطح المكتب',
            fg='#D1D5DB', bg=AMBER_BG, font=('Segoe UI', 11),
        ).pack(pady=(0, 16))

    def _add_row(self, parent, label, var, hint=None, row=None):
        frame = tk.Frame(parent, bg=WHITE)
        frame.pack(fill='x', padx=28, pady=6)
        tk.Label(
            frame, text=label, bg=WHITE, fg='#1F2937',
            font=('Segoe UI', 12), anchor='e', width=16,
        ).pack(side='right')
        entry = tk.Entry(
            frame, textvariable=var, font=('Segoe UI', 12),
            bg=FIELD_BG, relief='solid', bd=1,
        )
        entry.pack(side='left', fill='x', expand=True, ipady=4)
        if hint:
            tk.Label(
                parent, text=hint, bg=WHITE, fg='#6B7280',
                font=('Segoe UI', 10), anchor='e',
            ).pack(fill='x', padx=28, pady=(0, 2))
        return entry

    def _build_form(self):
        form = tk.Frame(self.root, bg=WHITE)
        form.pack(fill='both', expand=True, pady=(10, 0))

        self._add_row(form, 'اسم الفرع:', self.name_var, 'مثال: فرع إب')
        self._add_row(form, 'كود الفرع:', self.code_var, 'مثال: BR06 (مثل ما في النظام الأساسي)')
        self._add_row(
            form, 'معرف النظام:', self.sys_var,
            'مثال: branch6 — المعرّف الظاهر داخل النظام الأساسي عند إنشاء الفرع',
        )
        self._add_row(form, 'اسم المستخدم:', self.user_var, 'بيانات دخول الفرع الجديد (للتوثيق فقط)')
        self._add_row(form, 'كلمة المرور:', self.pass_var, 'بيانات دخول الفرع الجديد (للتوثيق فقط)')
        self._add_row(form, 'رابط الدخول:', self.url_var, '')

        self.sys_var.trace_add('write', lambda *_: self._update_url())

    def _build_footer(self):
        footer = tk.Frame(self.root, bg=WHITE)
        footer.pack(fill='x', pady=(6, 18))
        self.btn = tk.Button(
            footer, text='إنشاء التطبيق على سطح المكتب',
            command=self._create, bg=AMBER, fg=WHITE,
            activebackground='#92400E', activeforeground=WHITE,
            font=('Segoe UI', 13, 'bold'), relief='flat', bd=0,
            cursor='hand2',
        )
        self.btn.pack(fill='x', padx=28, ipady=10)
        tk.Label(
            footer, text='يُنشئ اختصاراً على سطح المكتب يفتح الفرع في Chrome كنافذة مستقلة',
            bg=WHITE, fg='#6B7280', font=('Segoe UI', 10),
        ).pack(pady=(8, 0))

    # ============ منطق ============
    def _update_url(self):
        sys_id = self.sys_var.get().strip()
        self.url_var.set(f'{HOST}/?sys={sys_id}' if sys_id else HOST)

    def _create(self):
        name = self.name_var.get().strip()
        sys_id = self.sys_var.get().strip()
        code = self.code_var.get().strip()
        url = self.url_var.get().strip()

        if not name or not sys_id:
            messagebox.showerror(
                'بيانات ناقصة',
                'الرجاء إدخال اسم الفرع ومعرف النظام (مثال: branch6).',
            )
            return
        if not url.startswith('http'):
            url = f'{HOST}/?sys={sys_id}'

        safe = _safe_name(name)
        try:
            desktop = _desktop_path()
            browser = _find_browser()
            shortcut = os.path.join(desktop, f'{safe} — تطبيق.lnk')
            description = f'النظام المحاسبي — {safe} ({code})'
            if browser:
                _create_lnk(shortcut, browser, url, description)
            else:
                shortcut = os.path.join(desktop, f'{safe} — تطبيق.url')
                _create_url_file(shortcut, url)
            messagebox.showinfo(
                'تم الإنشاء',
                f'تم إنشاء تطبيق «{safe}» على سطح المكتب بنجاح.\n\n'
                f'{shortcut}\n\n'
                f'رابط الدخول:\n{url}\n\n'
                f'اسم المستخدم: {self.user_var.get().strip()}\n'
                f'كلمة المرور: {self.pass_var.get()}\n\n'
                f'أو افتح الرابط من أي مكان:\n{HOST}/?sys={sys_id}',
            )
        except Exception as e:
            messagebox.showerror(
                'تعذّر الإنشاء',
                f'حدث خطأ أثناء إنشاء التطبيق:\n{e}\n\n'
                f'يمكنك استخدام الرابط مباشرة في المتصفح:\n{url}',
            )


def main():
    root = tk.Tk()
    BranchProgramApp(root)
    root.mainloop()
    return 0


if __name__ == '__main__':
    sys.exit(main())