using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
namespace OptikLentera.Win7
{
    public partial class MainWindow : Window
    {
        public MainWindow() { InitializeComponent(); }
        private void Navigate_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            if (button == null) return;
            var page = button.Tag as string ?? "Dashboard";
            PageTitle.Text = page;
            PageSubtitle.Text = page == "Dashboard" ? "Ringkasan aktivitas OPTIK LENTERA" : "Pratinjau menu " + page + " • Fitur transaksi belum diaktifkan";
            DashboardContent.Children.Clear();
            if (page == "Dashboard") { PageSubtitle.Text = "Ringkasan aktivitas OPTIK LENTERA"; return; }
            var panel = new Border { Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(236,230,218)), BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(14), Padding = new Thickness(28), Margin = new Thickness(0,4,0,0) };
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = page, FontSize = 21, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(35,34,30)), Margin = new Thickness(0,0,0,10) });
            stack.Children.Add(new TextBlock { Text = "Menu ini sudah masuk dalam rancangan prototipe OPTIK LENTERA.", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(105,100,91)), Margin = new Thickness(0,0,0,8) });
            stack.Children.Add(new TextBlock { Text = "Tahap uji saat ini hanya memeriksa aplikasi dapat dibuka, tampilan, dan perpindahan menu. Belum ada data pelanggan asli, transaksi, atau koneksi internet.", FontSize = 12, TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Color.FromRgb(132,125,114)), MaxWidth = 680 });
            panel.Child = stack;
            DashboardContent.Children.Add(panel);
        }
    }
}