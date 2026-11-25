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
        private string examinationFile;
        private TextBox nameBox, phoneBox, addressBox, searchBox;
        private DataGrid customerGrid;
        private TextBlock customerStatus, customerCount;

        private readonly ObservableCollection<Examination> examinations = new ObservableCollection<Examination>();
        private TextBox examCustomerBox, examDateBox, odSphBox, odCylBox, odAxisBox, odAddBox, odPdBox;
        private TextBox osSphBox, osCylBox, osAxisBox, osAddBox, osPdBox, examNotesBox, examSearchBox;
        private DataGrid examGrid;
        private TextBlock examStatus, examCount;

        public MainWindow()
        {
            InitializeComponent();
            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OptikLenteraWin7");
            customerFile = Path.Combine(folder, "pelanggan.json");
            examinationFile = Path.Combine(folder, "pemeriksaan.json");
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
            if (page == "Pemeriksaan Mata")
            {
                PageSubtitle.Text = "Catat resep OD dan OS secara lokal di komputer ini";
                BuildExaminationPage();
                return;
            }

            PageSubtitle.Text = "Pratinjau menu " + page + " • Fitur transaksi belum diaktifkan";
            var panel = MakePanel();
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = page, FontSize = 21, FontWeight = FontWeights.Bold, Foreground = Brush("#23221E"), Margin = new Thickness(0,0,0,10) });
            stack.Children.Add(new TextBlock { Text = "Menu ini sudah masuk dalam rancangan prototipe OPTIK LENTERA.", FontSize = 13, Foreground = Brush("#69645B"), Margin = new Thickness(0,0,0,8) });
            stack.Children.Add(new TextBlock { Text = "Tahap pengembangan berikutnya akan mengaktifkan fungsi menu ini satu per satu. Belum ada koneksi ke Android, Google Sheets, atau internet.", FontSize = 12, TextWrapping = TextWrapping.Wrap, Foreground = Brush("#847D72"), MaxWidth = 680 });
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
            nameBox = AddField(fields, "Nama pelanggan", 0, 0);
            phoneBox = AddField(fields, "Nomor WhatsApp", 0, 1);
            addressBox = AddField(fields, "Alamat (opsional)", 1, 0);
            Grid.SetColumnSpan(addressBox, 2);
            formStack.Children.Add(fields);

            var actions = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0,14,0,0) };
            var addButton = MakeActionButton("Simpan pelanggan");
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

        private void BuildExaminationPage()
        {
            LoadExaminations();
            var root = new StackPanel();
            var form = MakePanel();
            var formStack = new StackPanel();
            formStack.Children.Add(new TextBlock { Text = "FORM PEMERIKSAAN MATA", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), Margin = new Thickness(0,0,0,12) });
            formStack.Children.Add(new TextBlock { Text = "Isi data sesuai hasil pemeriksaan. Kolom yang tidak digunakan boleh dikosongkan.", FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,12) });

            var identity = new Grid();
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            examCustomerBox = AddField(identity, "Nama pelanggan", 0, 0);
            examDateBox = AddField(identity, "Tanggal (contoh: 25-11-2026)", 0, 1);
            examDateBox.Text = DateTime.Now.ToString("dd-MM-yyyy");
            formStack.Children.Add(identity);

            var eyeGrid = new Grid { Margin = new Thickness(0,4,0,0) };
            eyeGrid.ColumnDefinitions.Add(new ColumnDefinition());
            eyeGrid.ColumnDefinitions.Add(new ColumnDefinition());
            eyeGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            eyeGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var odPanel = MakeEyePanel("OD  •  MATA KANAN");
            var osPanel = MakeEyePanel("OS  •  MATA KIRI");
            Grid.SetColumn(odPanel, 0);
            Grid.SetColumn(osPanel, 1);
            eyeGrid.Children.Add(odPanel);
            eyeGrid.Children.Add(osPanel);
            odSphBox = AddEyeField(odPanel, "SPH", 0);
            odCylBox = AddEyeField(odPanel, "CYL", 1);
            odAxisBox = AddEyeField(odPanel, "AXIS", 2);
            odAddBox = AddEyeField(odPanel, "ADD", 3);
            odPdBox = AddEyeField(odPanel, "PD", 4);
            osSphBox = AddEyeField(osPanel, "SPH", 0);
            osCylBox = AddEyeField(osPanel, "CYL", 1);
            osAxisBox = AddEyeField(osPanel, "AXIS", 2);
            osAddBox = AddEyeField(osPanel, "ADD", 3);
            osPdBox = AddEyeField(osPanel, "PD", 4);
            formStack.Children.Add(eyeGrid);

            examNotesBox = new TextBox { Height = 58, Padding = new Thickness(9,7,9,7), FontSize = 12, AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Margin = new Thickness(0,8,0,0) };
            var notesStack = new StackPanel { Margin = new Thickness(0,6,0,0) };
            notesStack.Children.Add(new TextBlock { Text = "Catatan pemeriksaan (opsional)", FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,5) });
            notesStack.Children.Add(examNotesBox);
            formStack.Children.Add(notesStack);

            var actions = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0,14,0,0) };
            var save = MakeActionButton("Simpan pemeriksaan");
            save.Click += AddExamination_Click;
            actions.Children.Add(save);
            examStatus = new TextBlock { Text = "Data hanya tersimpan di komputer ini.", Foreground = Brush("#777168"), FontSize = 11, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(14,0,0,0) };
            actions.Children.Add(examStatus);
            formStack.Children.Add(actions);
            form.Child = formStack;
            root.Children.Add(form);

            var listPanel = MakePanel();
            listPanel.Margin = new Thickness(0,16,0,0);
            var listStack = new StackPanel();
            var header = new Grid();
            header.ColumnDefinitions.Add(new ColumnDefinition());
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(250) });
            examCount = new TextBlock { Text = "RIWAYAT PEMERIKSAAN", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), VerticalAlignment = VerticalAlignment.Center };
            header.Children.Add(examCount);
            examSearchBox = new TextBox { Height = 32, Padding = new Thickness(9,5,9,5), FontSize = 12, ToolTip = "Cari nama pelanggan" };
            examSearchBox.TextChanged += SearchExaminations_Changed;
            Grid.SetColumn(examSearchBox, 1);
            header.Children.Add(examSearchBox);
            listStack.Children.Add(header);

            examGrid = new DataGrid { AutoGenerateColumns = false, IsReadOnly = true, CanUserAddRows = false, HeadersVisibility = DataGridHeadersVisibility.Column, RowHeaderWidth = 0, Height = 230, Margin = new Thickness(0,14,0,0), Background = Brushes.White, BorderBrush = Brush("#ECE6DA"), BorderThickness = new Thickness(1), ItemsSource = examinations };
            examGrid.Columns.Add(new DataGridTextColumn { Header = "Tanggal", Binding = new System.Windows.Data.Binding("Date"), Width = 110 });
            examGrid.Columns.Add(new DataGridTextColumn { Header = "Pelanggan", Binding = new System.Windows.Data.Binding("CustomerName"), Width = new DataGridLength(1, DataGridLengthUnitType.Star) });
            examGrid.Columns.Add(new DataGridTextColumn { Header = "OD (SPH/CYL/AXIS)", Binding = new System.Windows.Data.Binding("ODSummary"), Width = 180 });
            examGrid.Columns.Add(new DataGridTextColumn { Header = "OS (SPH/CYL/AXIS)", Binding = new System.Windows.Data.Binding("OSSummary"), Width = 180 });
            listStack.Children.Add(examGrid);
            listPanel.Child = listStack;
            root.Children.Add(listPanel);
            DashboardContent.Children.Add(root);
            ApplyExaminationSearch();
        }

        private Border MakeEyePanel(string title)
        {
            var panel = MakePanel();
            panel.Margin = new Thickness(0,0,10,0);
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = title, FontSize = 12, FontWeight = FontWeights.Bold, Foreground = Brush("#A78342"), Margin = new Thickness(0,0,0,8) });
            var grid = new Grid();
            for (int i = 0; i < 5; i++) grid.ColumnDefinitions.Add(new ColumnDefinition());
            stack.Children.Add(grid);
            panel.Child = stack;
            panel.Tag = grid;
            return panel;
        }

        private TextBox AddEyeField(Border panel, string label, int column)
        {
            var grid = panel.Tag as Grid;
            var stack = new StackPanel { Margin = new Thickness(0,0,6,0) };
            stack.Children.Add(new TextBlock { Text = label, FontSize = 10, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,4) });
            var box = new TextBox { Height = 31, Padding = new Thickness(5,5,5,5), FontSize = 11 };
            stack.Children.Add(box);
            Grid.SetColumn(stack, column);
            grid.Children.Add(stack);
            return box;
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

        private Button MakeActionButton(string caption)
        {
            return new Button { Content = caption, Padding = new Thickness(18,9,18,9), Background = Brush("#20211F"), Foreground = Brush("#E6C982"), BorderThickness = new Thickness(0), FontWeight = FontWeights.SemiBold, Cursor = System.Windows.Input.Cursors.Hand };
        }

        private void AddCustomer_Click(object sender, RoutedEventArgs e)
        {
            var name = (nameBox.Text ?? "").Trim();
            var phone = (phoneBox.Text ?? "").Trim();
            var address = (addressBox.Text ?? "").Trim();
            if (name.Length == 0 || phone.Length == 0) { customerStatus.Text = "Nama dan nomor WhatsApp wajib diisi."; return; }
            if (customers.Any(c => string.Equals(c.Phone, phone, StringComparison.OrdinalIgnoreCase))) { customerStatus.Text = "Nomor WhatsApp sudah terdaftar."; return; }
            customers.Add(new Customer { Name = name, Phone = phone, Address = address });
            SaveCustomers();
            nameBox.Clear(); phoneBox.Clear(); addressBox.Clear();
            ApplyCustomerSearch();
            customerStatus.Text = "Pelanggan berhasil disimpan secara lokal.";
        }

        private void AddExamination_Click(object sender, RoutedEventArgs e)
        {
            var name = (examCustomerBox.Text ?? "").Trim();
            if (name.Length == 0) { examStatus.Text = "Nama pelanggan wajib diisi."; return; }
            var record = new Examination {
                CustomerName = name, Date = (examDateBox.Text ?? "").Trim(),
                ODSPH = Read(odSphBox), ODCYL = Read(odCylBox), ODAXIS = Read(odAxisBox), ODADD = Read(odAddBox), ODPD = Read(odPdBox),
                OSSPH = Read(osSphBox), OSCYL = Read(osCylBox), OSAXIS = Read(osAxisBox), OSADD = Read(osAddBox), OSPD = Read(osPdBox),
                Notes = Read(examNotesBox)
            };
            examinations.Add(record);
            SaveExaminations();
            examCustomerBox.Clear(); odSphBox.Clear(); odCylBox.Clear(); odAxisBox.Clear(); odAddBox.Clear(); odPdBox.Clear();
            osSphBox.Clear(); osCylBox.Clear(); osAxisBox.Clear(); osAddBox.Clear(); osPdBox.Clear(); examNotesBox.Clear();
            ApplyExaminationSearch();
            examStatus.Text = "Pemeriksaan berhasil disimpan secara lokal.";
        }

        private string Read(TextBox box) { return (box.Text ?? "").Trim(); }
        private void SearchCustomers_Changed(object sender, TextChangedEventArgs e) { ApplyCustomerSearch(); }
        private void SearchExaminations_Changed(object sender, TextChangedEventArgs e) { ApplyExaminationSearch(); }

        private void ApplyCustomerSearch()
        {
            if (customerGrid == null) return;
            var query = searchBox == null ? "" : (searchBox.Text ?? "").Trim();
            customerGrid.ItemsSource = customers.Where(c => query.Length == 0 || c.Name.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 || c.Phone.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 || c.Address.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            if (customerCount != null) customerCount.Text = "DAFTAR PELANGGAN  •  " + customers.Count + " data";
        }

        private void ApplyExaminationSearch()
        {
            if (examGrid == null) return;
            var query = examSearchBox == null ? "" : (examSearchBox.Text ?? "").Trim();
            examGrid.ItemsSource = examinations.Where(x => query.Length == 0 || x.CustomerName.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 || x.Date.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            if (examCount != null) examCount.Text = "RIWAYAT PEMERIKSAAN  •  " + examinations.Count + " data";
        }

        private void LoadCustomers()
        {
            customers.Clear();
            try { if (!File.Exists(customerFile)) return; var loaded = new JavaScriptSerializer().Deserialize<List<Customer>>(File.ReadAllText(customerFile)); if (loaded != null) foreach (var item in loaded) customers.Add(item); }
            catch { MessageBox.Show("Data pelanggan lokal belum dapat dibaca. File tidak dihapus.", "OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Warning); }
        }

        private void SaveCustomers()
        {
            try { var folder = Path.GetDirectoryName(customerFile); if (!Directory.Exists(folder)) Directory.CreateDirectory(folder); File.WriteAllText(customerFile, new JavaScriptSerializer().Serialize(customers.ToList())); }
            catch (Exception ex) { customerStatus.Text = "Gagal menyimpan: " + ex.Message; }
        }

        private void LoadExaminations()
        {
            examinations.Clear();
            try { if (!File.Exists(examinationFile)) return; var loaded = new JavaScriptSerializer().Deserialize<List<Examination>>(File.ReadAllText(examinationFile)); if (loaded != null) foreach (var item in loaded) examinations.Add(item); }
            catch { MessageBox.Show("Riwayat pemeriksaan lokal belum dapat dibaca. File tidak dihapus.", "OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Warning); }
        }

        private void SaveExaminations()
        {
            try { var folder = Path.GetDirectoryName(examinationFile); if (!Directory.Exists(folder)) Directory.CreateDirectory(folder); File.WriteAllText(examinationFile, new JavaScriptSerializer().Serialize(examinations.ToList())); }
            catch (Exception ex) { examStatus.Text = "Gagal menyimpan: " + ex.Message; }
        }

        private Border MakePanel()
        {
            return new Border { Background = Brushes.White, BorderBrush = Brush("#ECE6DA"), BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(14), Padding = new Thickness(22) };
        }

        private SolidColorBrush Brush(string hex) { return new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex)); }

        public class Customer { public string Name { get; set; } public string Phone { get; set; } public string Address { get; set; } }

        public class Examination
        {
            public string CustomerName { get; set; } public string Date { get; set; }
            public string ODSPH { get; set; } public string ODCYL { get; set; } public string ODAXIS { get; set; } public string ODADD { get; set; } public string ODPD { get; set; }
            public string OSSPH { get; set; } public string OSCYL { get; set; } public string OSAXIS { get; set; } public string OSADD { get; set; } public string OSPD { get; set; }
            public string Notes { get; set; }
            public string ODSummary { get { return ODSPH + " / " + ODCYL + " / " + ODAXIS; } }
            public string OSSummary { get { return OSSPH + " / " + OSCYL + " / " + OSAXIS; } }
        }
    }
}