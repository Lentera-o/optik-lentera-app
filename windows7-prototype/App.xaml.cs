using System;
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
                Environment.ExitCode = MainWindow.RunPrintLayoutSmoke(output);
                Shutdown();
                return;
            }

            var main = new MainWindow();
            MainWindow = main;
            main.Show();
        }
    }
}
