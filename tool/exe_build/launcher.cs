// مشغّل نظام محاسبي (C#) — يفتح النظام المحدد في Chrome/Edge كتطبيق مستقل.
//
// - كل شيء عبر Firebase السحابية: يعمل من أي مكان ومن أي جهاز.
// - التطبيقات المُصدَّرة من تطبيق الأدمن (تنزيل ويب) يُلحق معرف النظام
//   في ذيل الـ EXE (علامة @@ZSYS=...@@) — تُقرأ هنا مباشرة.
// - بلا علامة: يفتح النظام الأساسي (admin).
//
// البناء:
//   csc /target:winexe /win32icon:windows\runner\resources\app_icon.ico
//      /out:apps\launcher.exe tool\exe_build\launcher.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Text;

internal static class Launcher
{
    private const string Host = "https://accountingsystem-fc3f0.web.app";
    private const string Version = "20260918-1";

    [STAThread]
    private static int Main()
    {
        string mode = FindMarker();
        if (string.IsNullOrEmpty(mode)) mode = "admin";
        string url = Host + "/?v=" + Version + "&sys=" + Uri.EscapeDataString(mode);

        string browser = FindBrowser();
        if (browser != null)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = browser,
                    Arguments = "--app=" + url + " --new-window",
                    UseShellExecute = false,
                });
                return 0;
            }
            catch { }
        }
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true,
            });
        }
        catch { }
        return 0;
    }

    /// <summary>معرف النظام الملحق بذيل الـ EXE (علامة @@ZSYS=...@@).</summary>
    private static string FindMarker()
    {
        try
        {
            string path = Process.GetCurrentProcess().MainModule.FileName;
            using (FileStream fs = new FileStream(
                path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                long size = fs.Length;
                int tailLen = (int)Math.Min(512, size);
                fs.Seek(size - tailLen, SeekOrigin.Begin);
                byte[] buf = new byte[tailLen];
                int read = fs.Read(buf, 0, tailLen);
                string tail = Encoding.UTF8.GetString(buf, 0, read);
                int i = tail.IndexOf("@@ZSYS=", StringComparison.Ordinal);
                if (i >= 0)
                {
                    int j = tail.IndexOf("@@", i + 7, StringComparison.Ordinal);
                    if (j > i)
                    {
                        string mode = tail.Substring(i + 7, j - i - 7).Trim();
                        if (mode.Length > 0) return mode;
                    }
                }
            }
        }
        catch { }
        return null;
    }

    private static string FindBrowser()
    {
        string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        string pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        string la = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string[] candidates = new string[]
        {
            la + @"\Google\Chrome\Application\chrome.exe",
            pf + @"\Google\Chrome\Application\chrome.exe",
            pf86 + @"\Google\Chrome\Application\chrome.exe",
            la + @"\Microsoft\Edge\Application\msedge.exe",
            pf + @"\Microsoft\Edge\Application\msedge.exe",
            pf86 + @"\Microsoft\Edge\Application\msedge.exe",
        };
        foreach (string c in candidates)
        {
            try { if (File.Exists(c)) return c; } catch { }
        }
        return null;
    }
}
