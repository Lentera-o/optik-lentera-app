using System;
using System.IO;
using System.Windows;

namespace OptikLentera.Win7
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            if (e.Args.Length > 0 && string.Equals(e.Args[0], "--print-layout-smoke", StringComparison.OrdinalIgnoreCase))
            {
                string output = e.Args.Length > 1 ? e.Args[1] : "print-layout-proof";
                try
                {
                    Directory.CreateDirectory(output);
                    File.WriteAllText(Path.Combine(output, "STARTUP.txt"), "Smoke mode entered. Args: " + string.Join(" | ", e.Args));
                    int code = OptikLentera.Win7.MainWindow.RunPrintLayoutSmoke(output);
                    File.WriteAllText(Path.Combine(output, "EXIT-CODE.txt"), code.ToString());
                    Shutdown(code);
                }
                catch (Exception ex)
                {
                    Directory.CreateDirectory(output);
                    File.WriteAllText(Path.Combine(output, "STARTUP-FAILED.txt"), ex.ToString());
                    Shutdown(2);
                }
                return;
            }

            var main = new MainWindow();
            MainWindow = main;
            main.Show();
        }
    }
}
