using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Web.Script.Serialization;

namespace OptikLentera.Win7
{
    public partial class MainWindow : Window
    {
        private readonly ObservableCollection<Customer> customers = new ObservableCollection<Customer>();
        private string customerFile;
        private TextBox nameBox, phoneBox, addressBox, searchBox;
        private DataGrid customerGrid;
        private TextBlock customerStatus, customerCount;

        public MainWindow()
        {
            InitializeComponent();
            customerFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OptikLenteraWin7", "pelanggan.json");
        }

        private void Navigate_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            if (button == null) return;
            var page = button.Tag as string ?? "Dashboard";
            PageTitle.Text = page;
            DashboardContent.Children.Clear();

            if (page == "Dashboard")
            {
                PageSubtitle.Text = "Ringkasan aktivitas OPTIK LENTERA";
                BuildDashboardPlaceholder();
                return;
            }

            if (page == "Pelanggan")
            {
                PageSubtitle.Text = "Data pelanggan tersimpan lokal di komputer ini";
                BuildCustomerPage();
                return;
            }

            PageSubtitle.Text = "Pratinjau menu " + page + " • Fitur transaksi belum diaktifkan";
            var panel = MakePanel();
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = page, FontSize = 21, FontWeight = FontWeights.Bold, Foreground = Brush("#23221E"), Margin = new Thickness(0,0,0,10) });
            stack.Children.Add(new TextBlock { Text = "Menu ini sudah masuk dalam rancangan prototipe OPTIK LENTERA.", FontSize = 13, Foreground = Brush("#69645B"), Margin = new Thickness(0,0,0,8) });
            stack.Children.Add(new TextBlock { Text = "Tahap pengembangan berikutnya akan mengaktifkan fungsi menu ini satu per satu. Belum ada koneksi ke Android, Google Sheets, atau internet.", FontSize = 12, TextWrapping = TextWrapping.Wrap, Foreground = Brush("#847D72),", MaxWidth = 680 });
            panel.Child = stack;
            DashboardContent.Children.Add(panel);
        }

        private void BuildDashboardPlaceholder()
        {
            var panel = MakePanel();
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = "JELAS LIHATNYA, JELAS REJEKINYA", FontSize = 18, FontWeight = FontWeights.Bold, Foreground = Brush("#B18D4D") });
            stack.Children.Add(new TextBlock { Text = "Workspace desktop OPTIK LENTERA siap dikembangkan.", FontSize = 13, Foreground = Brush("#69645B"), Margin = new Thickness(0,10,0,0) });
            panel.Child = stack;
            DashboardContent.Children.Add(panel);
        }

        private void BuildCustomerPage()
        {
            LoadCustomers();
            var root = new StackPanel();
            var form = MakePanel();
            var formStack = new StackPanel();
            formStack.Children.Add(new TextBlock { Text = "TAMBAH PELANGGAN", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), Margin = new Thickness(0,0,0,14) });

            var fields = new Grid();
            fields.ColumnDefinitions.Add(new ColumnDefinition());
            fields.ColumnDefinitions.Add(new ColumnDefinition());
            fields.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            fields.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            fields.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            nameBox = AddField(fields, "Nama pelanggan", 0, 0);
            phoneBox = AddField(fields, "Nomor WhatsApp", 0, 1);
            addressBox = AddField(fields, "Alamat (opsional)", 1, 0);
            Grid.SetColumnSpan(addressBox, 2);
            formStack.Children.Add(fields);

            var actions = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0,14,0,0) };
            var addButton = new Button { Content = "Simpan pelanggan", Padding = new Thickness(18,9,18,9), Background = Brush("#20211F"), Foreground = Brush("#E6C982"), BorderThickness = new Thickness(0), FontWeight = FontWeights.SemiBold, Cursor = System.Windows.Input.Cursors.Hand };
            addButton.Click += AddCustomer_Click;
            actions.Children.Add(addButton);
            customerStatus = new TextBlock { Text = "Data disimpan hanya di komputer ini.", Foreground = Brush("#777168"), FontSize = 11, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(14,0,0,0) };
            actions.Children.Add(customerStatus);
            formStack.Children.Add(actions);
            form.Child = formStack;
            root.Children.Add(form);

            var listPanel = MakePanel();
            listPanel.Margin = new Thickness(0,16,0,0);
            var listStack = new StackPanel();
            var header = new Grid();
            header.ColumnDefinitions.Add(new ColumnDefinition());
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(260) });
            customerCount = new TextBlock { Text = "DAFTAR PELANGGAN", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), VerticalAlignment = VerticalAlignment.Center };
            header.Children.Add(customerCount);
            searchBox = new TextBox { Height = 32, Padding = new Thickness(9,5,9,5), FontSize = 12, ToolTip = "Cari nama atau nomor WhatsApp" };
            searchBox.TextChanged += SearchCustomers_Changed;
            Grid.SetColumn(searchBox, 1);
            header.Children.Add(searchBox);
            listStack.Children.Add(header);

            customerGrid = new DataGrid { AutoGenerateColumns = false, IsReadOnly = true, CanUserAddRows = false, HeadersVisibility = DataGridHeadersVisibility.Column, RowHeaderWidth = 0, Height = 300, Margin = new Thickness(0,14,0,0), Background = Brushes.White, BorderBrush = Brush("#ECE6DA"), BorderThickness = new Thickness(1), ItemsSource = customers };
            customerGrid.Columns.Add(new DataGridTextColumn { Header = "Nama", Binding = new System.Windows.Data.Binding("Name"), Width = new DataGridLength(1, DataGridLengthUnitType.Star) });
            customerGrid.Columns.Add(new DataGridTextColumn { Header = "WhatsApp", Binding = new System.Windows.Data.Binding("Phone"), Width = new DataGridLength(180) });
            customerGrid.Columns.Add(new DataGridTextColumn { Header = "Alamat", Binding = new System.Windows.Data.Binding("Address"), Width = new DataGridLength(2, DataGridLengthUnitType.Star) });
            listStack.Children.Add(customerGrid);
            listPanel.Child = listStack;
            root.Children.Add(listPanel);
            DashboardContent.Children.Add(root);
            ApplyCustomerSearch();
        }

        private TextBox AddField(Grid grid, string hint, int row, int column)
        {
            var wrap = new StackPanel { Margin = new Thickness(column == 0 ? 0 : 10, 0, 0, 10) };
            wrap.Children.Add(new TextBlock { Text = hint, FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,5) });
            var box = new TextBox { Height = 34, Padding = new Thickness(9,6,9,6), FontSize = 12 };
            wrap.Children.Add(box);
            Grid.SetRow(wrap, row);
            Grid.SetColumn(wrap, column);
            grid.Children.Add(wrap);
            return box;
        }

        private void AddCustomer_Click(object sender, RoutedEventArgs e)
        {
            var name = (nameBox.Text ?? "").Trim();
            var phone = (phoneBox.Text ?? "").Trim();
            var address = (addressBox.Text ?? "").Trim();
            if (name.Length == 0 || phone.Length == 0)
            {
                customerStatus.Text = "Nama dan nomor WhatsApp wajib diisi.";
                return;
            }
            if (customers.Any(c => string.Equals(c.Phone, phone, StringComparison.OrdinalIgnoreCase)))
            {
                customerStatus.Text = "Nomor WhatsApp sudah terdaftar.";
                return;
            }
            customers.Add(new Customer { Name = name, Phone = phone, Address = address });
            SaveCustomers();
            nameBox.Clear(); phoneBox.Clear(); addressBox.Clear();
            ApplyCustomerSearch();
            customerStatus.Text = "Pelanggan berhasil disimpan secara lokal.";
        }

        private void SearchCustomers_Changed(object sender, TextChangedEventArgs e) { ApplyCustomerSearch(); }

        private void ApplyCustomerSearch()
        {
            if (customerGrid == null) return;
            var query = searchBox == null ? "" : (searchBox.Text ?? "").Trim();
            var rows = customers.Where(c => query.Length == 0 ||
                c.Name.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 ||
                c.Phone.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 ||
                c.Address.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            customerGrid.ItemsSource = rows;
            if (customerCount != null) customerCount.Text = "DAFTAR PELANGGAN  •  " + customers.Count + " data";
        }

        private void LoadCustomers()
        {
            customers.Clear();
            try
            {
                if (!File.Exists(customerFile)) return;
                var json = File.ReadAllText(customerFile);
                var loaded = new JavaScriptSerializer().Deserialize<List<Customer>>(json);
                if (loaded != null) foreach (var customer in loaded) customers.Add(customer);
            }
            catch { MessageBox.Show("Data pelanggan lokal belum dapat dibaca. File tidak dihapus.", "OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Warning); }
        }

        private void SaveCustomers()
        {
            try
            {
                var folder = Path.GetDirectoryName(customerFile);
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
                File.WriteAllText(customerFile, new JavaScriptSerializer().Serialize(customers.ToList()));
            }
            catch (Exception ex)
            {
                customerStatus.Text = "Gagal menyimpan: " + ex.Message;
            }
        }

        private Border MakePanel()
        {
            return new Border { Background = Brushes.White, BorderBrush = Brush("#ECE6DA"), BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(14), Padding = new Thickness(22) };
        }

        private SolidColorBrush Brush(string hex)
        {
            return new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
        }

        public class Customer
        {
            public string Name { get; set; }
            public string Phone { get; set; }
            public string Address { get; set; }
        }
    }
}