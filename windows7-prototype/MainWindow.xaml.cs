using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using Path = System.IO.Path;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Web.Script.Serialization;
using QRCoder;

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

        private readonly ObservableCollection<Order> orders = new ObservableCollection<Order>();
        private string orderFile;
        private ComboBox orderCustomerBox;
        private TextBox orderDateBox, frameBrandBox, frameModelBox, frameColorBox, framePriceBox;
        private TextBox lensTypeBox, lensSizeBox, lensCoatingBox, lensPriceBox, otherItemBox, otherPriceBox, orderNotesBox, orderSearchBox;
        private TextBlock orderTotalText, orderStatus, orderCount;
        private DataGrid orderGrid;

        private readonly ObservableCollection<Payment> payments = new ObservableCollection<Payment>();
        private string paymentFile;
        private ComboBox paymentOrderBox, paymentMethodBox;
        private TextBox paymentDateBox, paymentAmountBox, paymentNotesBox, paymentSearchBox;
        private TextBlock paymentTotalText, paymentPaidText, paymentRemainingText, paymentStatus, paymentCount;
        private DataGrid paymentGrid;
        private ComboBox documentOrderBox, documentPaymentBox, documentExamBox;
        private Border documentPreview;
        private TextBlock documentStatus;

        public MainWindow()
        {
            InitializeComponent();
            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OptikLenteraWin7");
            customerFile = Path.Combine(folder, "pelanggan.json");
            examinationFile = Path.Combine(folder, "pemeriksaan.json");
            orderFile = Path.Combine(folder, "pesanan.json");
            paymentFile = Path.Combine(folder, "pembayaran.json");
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
            if (page == "Pesanan")
            {
                PageSubtitle.Text = "Kelola detail frame, lensa, dan nilai pesanan secara lokal";
                BuildOrderPage();
                return;
            }
            if (page == "Pembayaran")
            {
                PageSubtitle.Text = "Catat DP dan pelunasan, saldo dihitung otomatis";
                BuildPaymentPage();
                return;
            }
            if (page == "Invoice & Kuitansi")
            {
                PageSubtitle.Text = "Cetak invoice pesanan dan kuitansi pembayaran";
                BuildInvoicePage();
                return;
            }
            if (page == "Laporan")
            {
                PageSubtitle.Text = "Ringkasan pesanan dan pembayaran lokal";
                BuildReportPage();
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
            var printExam = MakeActionButton("Cetak Resep Terpilih");
            printExam.Margin = new Thickness(0,12,0,0);
            printExam.HorizontalAlignment = HorizontalAlignment.Left;
            printExam.Click += PrintExamination_Click;
            listStack.Children.Add(printExam);
            listPanel.Child = listStack;
            root.Children.Add(listPanel);
            DashboardContent.Children.Add(root);
            ApplyExaminationSearch();
        }

        private void BuildOrderPage()
        {
            LoadCustomers();
            LoadOrders();
            var root = new StackPanel();

            var form = MakePanel();
            var formStack = new StackPanel();
            formStack.Children.Add(new TextBlock { Text = "BUAT PESANAN BARU", FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), Margin = new Thickness(0,0,0,5) });
            formStack.Children.Add(new TextBlock { Text = "Pilih pelanggan, lengkapi frame dan lensa. Total dihitung otomatis.", FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,14) });

            var identity = new Grid();
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var customerWrap = new StackPanel { Margin = new Thickness(0,0,10,10) };
            customerWrap.Children.Add(new TextBlock { Text = "Pelanggan", FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,5) });
            orderCustomerBox = new ComboBox { Height = 34, Padding = new Thickness(7,5,7,5), FontSize = 12, ItemsSource = customers, DisplayMemberPath = "Name" };
            if (customers.Count > 0) orderCustomerBox.SelectedIndex = 0;
            customerWrap.Children.Add(orderCustomerBox);
            identity.Children.Add(customerWrap);
            orderDateBox = AddField(identity, "Tanggal pesanan", 0, 1);
            orderDateBox.Text = DateTime.Now.ToString("dd-MM-yyyy");
            formStack.Children.Add(identity);

            formStack.Children.Add(SectionCaption("DETAIL FRAME"));
            var frameGrid = MakeInputGrid();
            frameBrandBox = AddField(frameGrid, "Merek frame", 0, 0);
            frameModelBox = AddField(frameGrid, "Model", 0, 1);
            frameColorBox = AddField(frameGrid, "Warna", 0, 2);
            framePriceBox = AddField(frameGrid, "Harga frame (Rp)", 1, 0);
            formStack.Children.Add(frameGrid);

            formStack.Children.Add(SectionCaption("DETAIL LENSA"));
            var lensGrid = MakeInputGrid();
            lensTypeBox = AddField(lensGrid, "Jenis lensa", 0, 0);
            lensSizeBox = AddField(lensGrid, "Ukuran / indeks", 0, 1);
            lensCoatingBox = AddField(lensGrid, "Coating", 0, 2);
            lensPriceBox = AddField(lensGrid, "Harga lensa (Rp)", 1, 0);
            formStack.Children.Add(lensGrid);

            formStack.Children.Add(SectionCaption("TAMBAHAN & CATATAN"));
            var otherGrid = MakeInputGrid();
            otherItemBox = AddField(otherGrid, "Barang / biaya tambahan", 0, 0);
            otherPriceBox = AddField(otherGrid, "Harga tambahan (Rp)", 0, 1);
            orderNotesBox = AddField(otherGrid, "Catatan pesanan (opsional)", 0, 2);
            formStack.Children.Add(otherGrid);

            var footer = new Grid { Margin = new Thickness(0,12,0,0) };
            footer.ColumnDefinitions.Add(new ColumnDefinition());
            footer.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            var actions = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            var save = MakeActionButton("Simpan pesanan");
            save.Click += AddOrder_Click;
            actions.Children.Add(save);
            orderStatus = new TextBlock { Text = "Data pesanan tersimpan lokal di komputer ini.", Foreground = Brush("#777168"), FontSize = 11, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12,0,0,0) };
            actions.Children.Add(orderStatus);
            footer.Children.Add(actions);
            var totalPanel = new Border { Background = Brush("#20211F"), CornerRadius = new CornerRadius(10), Padding = new Thickness(18,10,18,10), Margin = new Thickness(12,0,0,0) };
            var totalStack = new StackPanel();
            totalStack.Children.Add(new TextBlock { Text = "TOTAL PESANAN", Foreground = Brush("#C8A45D"), FontSize = 10, FontWeight = FontWeights.Bold });
            orderTotalText = new TextBlock { Text = "Rp 0", Foreground = Brush("#F7F3EA"), FontSize = 21, FontWeight = FontWeights.Bold, Margin = new Thickness(0,3,0,0) };
            totalStack.Children.Add(orderTotalText);
            totalPanel.Child = totalStack;
            Grid.SetColumn(totalPanel, 1);
            footer.Children.Add(totalPanel);
            formStack.Children.Add(footer);
            form.Child = formStack;
            root.Children.Add(form);

            var listPanel = MakePanel();
            listPanel.Margin = new Thickness(0,16,0,0);
            var listStack = new StackPanel();
            var header = new Grid();
            header.ColumnDefinitions.Add(new ColumnDefinition());
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(250) });
            orderCount = new TextBlock { Text = "DAFTAR PESANAN", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), VerticalAlignment = VerticalAlignment.Center };
            header.Children.Add(orderCount);
            orderSearchBox = new TextBox { Height = 32, Padding = new Thickness(9,5,9,5), FontSize = 12, ToolTip = "Cari pelanggan, frame, atau lensa" };
            orderSearchBox.TextChanged += SearchOrders_Changed;
            Grid.SetColumn(orderSearchBox, 1);
            header.Children.Add(orderSearchBox);
            listStack.Children.Add(header);

            orderGrid = new DataGrid { AutoGenerateColumns = false, IsReadOnly = true, CanUserAddRows = false, HeadersVisibility = DataGridHeadersVisibility.Column, RowHeaderWidth = 0, Height = 250, Margin = new Thickness(0,14,0,0), Background = Brushes.White, BorderBrush = Brush("#ECE6DA"), BorderThickness = new Thickness(1), ItemsSource = orders };
            orderGrid.Columns.Add(new DataGridTextColumn { Header = "Tanggal", Binding = new System.Windows.Data.Binding("Date"), Width = 105 });
            orderGrid.Columns.Add(new DataGridTextColumn { Header = "Pelanggan", Binding = new System.Windows.Data.Binding("CustomerName"), Width = new DataGridLength(1, DataGridLengthUnitType.Star) });
            orderGrid.Columns.Add(new DataGridTextColumn { Header = "Frame", Binding = new System.Windows.Data.Binding("FrameDescription"), Width = 170 });
            orderGrid.Columns.Add(new DataGridTextColumn { Header = "Lensa", Binding = new System.Windows.Data.Binding("LensDescription"), Width = 170 });
            orderGrid.Columns.Add(new DataGridTextColumn { Header = "Total", Binding = new System.Windows.Data.Binding("TotalDisplay"), Width = 130 });
            listStack.Children.Add(orderGrid);
            listPanel.Child = listStack;
            root.Children.Add(listPanel);
            DashboardContent.Children.Add(root);

            framePriceBox.TextChanged += OrderPrice_Changed;
            lensPriceBox.TextChanged += OrderPrice_Changed;
            otherPriceBox.TextChanged += OrderPrice_Changed;
            UpdateOrderTotal();
            ApplyOrderSearch();
        }


        private void BuildPaymentPage()
        {
            LoadOrders();
            LoadPayments();
            LoadExaminations();
            var root = new StackPanel();
            var form = MakePanel();
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = "CATAT PEMBAYARAN", FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), Margin = new Thickness(0,0,0,5) });
            stack.Children.Add(new TextBlock { Text = "Pilih pesanan, masukkan DP atau pelunasan. Saldo dihitung dari seluruh pembayaran yang tersimpan.", FontSize = 11, Foreground = Brush("#777168"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,0,0,12) });

            var identity = new Grid();
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var orderWrap = new StackPanel { Margin = new Thickness(0,0,10,10) };
            orderWrap.Children.Add(new TextBlock { Text = "Pesanan pelanggan", FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,5) });
            paymentOrderBox = new ComboBox { Height = 34, Padding = new Thickness(7,5,7,5), FontSize = 12, DisplayMemberPath = "PaymentLabel" };
            paymentOrderBox.ItemsSource = orders;
            paymentOrderBox.SelectionChanged += PaymentOrder_Changed;
            orderWrap.Children.Add(paymentOrderBox);
            identity.Children.Add(orderWrap);
            paymentDateBox = AddField(identity, "Tanggal pembayaran", 0, 1);
            paymentDateBox.Text = DateTime.Now.ToString("dd-MM-yyyy");
            stack.Children.Add(identity);

            var moneyGrid = MakeInputGrid();
            paymentAmountBox = AddField(moneyGrid, "Jumlah dibayar (Rp)", 0, 0);
            paymentMethodBox = new ComboBox { Height = 34, Padding = new Thickness(7,5,7,5), FontSize = 12, Margin = new Thickness(10,0,0,10) };
            paymentMethodBox.Items.Add("Tunai");
            paymentMethodBox.Items.Add("Transfer");
            paymentMethodBox.Items.Add("QRIS");
            paymentMethodBox.Items.Add("Debit / Kredit");
            paymentMethodBox.Items.Add("Lainnya");
            paymentMethodBox.SelectedIndex = 0;
            var methodWrap = new StackPanel { Margin = new Thickness(10,0,0,10) };
            methodWrap.Children.Add(new TextBlock { Text = "Metode pembayaran", FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,5) });
            methodWrap.Children.Add(paymentMethodBox);
            Grid.SetRow(methodWrap, 0);
            Grid.SetColumn(methodWrap, 1);
            moneyGrid.Children.Add(methodWrap);
            paymentNotesBox = AddField(moneyGrid, "Catatan (opsional)", 0, 2);
            stack.Children.Add(moneyGrid);

            var balance = new Border { Background = Brush("#20211F"), CornerRadius = new CornerRadius(10), Padding = new Thickness(16,12,16,12), Margin = new Thickness(0,5,0,0) };
            var balanceGrid = new Grid();
            for (int i = 0; i < 3; i++) balanceGrid.ColumnDefinitions.Add(new ColumnDefinition());
            paymentTotalText = BalanceValue(balanceGrid, "TOTAL PESANAN", "Rp 0", 0);
            paymentPaidText = BalanceValue(balanceGrid, "SUDAH DIBAYAR", "Rp 0", 1);
            paymentRemainingText = BalanceValue(balanceGrid, "SISA TAGIHAN", "Rp 0", 2);
            balance.Child = balanceGrid;
            stack.Children.Add(balance);

            var actions = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0,14,0,0) };
            var save = MakeActionButton("Simpan pembayaran");
            save.Click += AddPayment_Click;
            actions.Children.Add(save);
            paymentStatus = new TextBlock { Text = "Pembayaran tersimpan lokal di komputer ini.", Foreground = Brush("#777168"), FontSize = 11, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12,0,0,0) };
            actions.Children.Add(paymentStatus);
            stack.Children.Add(actions);
            form.Child = stack;
            root.Children.Add(form);

            var listPanel = MakePanel();
            listPanel.Margin = new Thickness(0,16,0,0);
            var listStack = new StackPanel();
            var header = new Grid();
            header.ColumnDefinitions.Add(new ColumnDefinition());
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(250) });
            paymentCount = new TextBlock { Text = "RIWAYAT PEMBAYARAN", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), VerticalAlignment = VerticalAlignment.Center };
            header.Children.Add(paymentCount);
            paymentSearchBox = new TextBox { Height = 32, Padding = new Thickness(9,5,9,5), FontSize = 12, ToolTip = "Cari nomor kuitansi atau pelanggan" };
            paymentSearchBox.TextChanged += SearchPayments_Changed;
            Grid.SetColumn(paymentSearchBox, 1);            header.Children.Add(paymentSearchBox);
            listStack.Children.Add(header);

            paymentGrid = new DataGrid { AutoGenerateColumns = false, IsReadOnly = true, CanUserAddRows = false, HeadersVisibility = DataGridHeadersVisibility.Column, RowHeaderWidth = 0, Height = 260, Margin = new Thickness(0,14,0,0), Background = Brushes.White, BorderBrush = Brush("#ECE6DA"), BorderThickness = new Thickness(1), ItemsSource = payments };
            paymentGrid.Columns.Add(new DataGridTextColumn { Header = "No. Kuitansi", Binding = new System.Windows.Data.Binding("ReceiptNumber"), Width = 165 });
            paymentGrid.Columns.Add(new DataGridTextColumn { Header = "Tanggal", Binding = new System.Windows.Data.Binding("Date"), Width = 105 });
            paymentGrid.Columns.Add(new DataGridTextColumn { Header = "Pelanggan", Binding = new System.Windows.Data.Binding("CustomerName"), Width = new DataGridLength(1, DataGridLengthUnitType.Star) });
            paymentGrid.Columns.Add(new DataGridTextColumn { Header = "Metode", Binding = new System.Windows.Data.Binding("Method"), Width = 120 });
            paymentGrid.Columns.Add(new DataGridTextColumn { Header = "Dibayar", Binding = new System.Windows.Data.Binding("AmountDisplay"), Width = 130 });
            listStack.Children.Add(paymentGrid);
            listPanel.Child = listStack;
            root.Children.Add(listPanel);
            DashboardContent.Children.Add(root);

            if (orders.Count > 0) paymentOrderBox.SelectedIndex = 0;
            UpdatePaymentBalance();
            ApplyPaymentSearch();
        }


        private void BuildInvoicePage()
        {
            LoadOrders();
            LoadPayments();
            var root = new StackPanel();
            var panel = MakePanel();
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = "DOKUMEN TRANSAKSI", FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), Margin = new Thickness(0,0,0,12) });
            var selectors = new Grid();
            selectors.ColumnDefinitions.Add(new ColumnDefinition());
            selectors.ColumnDefinitions.Add(new ColumnDefinition());
            var ow = new StackPanel { Margin = new Thickness(0,0,10,10) };
            ow.Children.Add(new TextBlock { Text = "Pilih pesanan / invoice", FontSize = 11, Foreground = Brush("#777168") });
            documentOrderBox = new ComboBox { Height = 34, DisplayMemberPath = "PaymentLabel", ItemsSource = orders };
            documentOrderBox.SelectionChanged += DocumentOrder_Changed;
            ow.Children.Add(documentOrderBox);
            selectors.Children.Add(ow);
            var pw = new StackPanel { Margin = new Thickness(10,0,0,10) };
            pw.Children.Add(new TextBlock { Text = "Pilih kuitansi pembayaran", FontSize = 11, Foreground = Brush("#777168") });
            documentPaymentBox = new ComboBox { Height = 34, DisplayMemberPath = "ReceiptNumber" };
            documentPaymentBox.SelectionChanged += DocumentPayment_Changed;
            pw.Children.Add(documentPaymentBox);
            Grid.SetColumn(pw, 1);
            selectors.Children.Add(pw);
            stack.Children.Add(selectors);
            var examWrap = new StackPanel { Margin = new Thickness(0,4,0,8) };
            examWrap.Children.Add(new TextBlock { Text = "Pilih hasil pemeriksaan untuk mencetak resep", FontSize = 11, Foreground = Brush("#777168"), Margin = new Thickness(0,0,0,5) });
            documentExamBox = new ComboBox { Height = 34, DisplayMemberPath = "ExamLabel", ItemsSource = examinations };
            if (examinations.Count > 0) documentExamBox.SelectedIndex = examinations.Count - 1;
            examWrap.Children.Add(documentExamBox);
            stack.Children.Add(examWrap);
            var actions = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0,8,0,12) };
            var ib = MakeActionButton("Cetak Invoice"); ib.Click += PrintInvoice_Click; actions.Children.Add(ib);
            var rb = MakeActionButton("Cetak Kuitansi"); rb.Margin = new Thickness(10,0,0,0); rb.Click += PrintReceipt_Click; actions.Children.Add(rb);
            var eb = MakeActionButton("Cetak Resep"); eb.Margin = new Thickness(10,0,0,0); eb.Click += PrintSelectedExamination_Click; actions.Children.Add(eb);
            documentStatus = new TextBlock { Text = "Pilih pesanan atau pemeriksaan untuk mencetak dokumen.", FontSize = 11, Foreground = Brush("#777168"), VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12,0,0,0) };
            actions.Children.Add(documentStatus);
            stack.Children.Add(actions);
            panel.Child = stack; root.Children.Add(panel);
            var preview = MakePanel(); preview.Margin = new Thickness(0,14,0,0);
            documentPreview = new Border { Background = Brushes.White, Padding = new Thickness(28), BorderBrush = Brush("#D8CBAE"), BorderThickness = new Thickness(1), MinHeight = 280 };
            preview.Child = documentPreview; root.Children.Add(preview);
            DashboardContent.Children.Add(root);
            if (orders.Count > 0) documentOrderBox.SelectedIndex = 0;
            RefreshDocumentPayments(); UpdateDocumentPreview();
        }

        private void DocumentOrder_Changed(object sender, SelectionChangedEventArgs e) { RefreshDocumentPayments(); UpdateDocumentPreview(); }
        private void DocumentPayment_Changed(object sender, SelectionChangedEventArgs e) { UpdateDocumentPreview(); }

        private void RefreshDocumentPayments()
        {
            if (documentPaymentBox == null) return;
            var order = documentOrderBox == null ? null : documentOrderBox.SelectedItem as Order;
            documentPaymentBox.ItemsSource = order == null ? new List<Payment>() : payments.Where(p => p.OrderKey == order.OrderKey).OrderBy(p => p.Date).ToList();
            if (documentPaymentBox.Items.Count > 0) documentPaymentBox.SelectedIndex = documentPaymentBox.Items.Count - 1;
        }

        private Border MakeLetterhead(bool printMode)
        {
            var header = new Grid { Margin = new Thickness(0,0,0,12) };
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(112) });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            var logo = new Image
            {
                Source = CreatePrintLogoSource(),
                Width = 100, Height = 78, Stretch = Stretch.Uniform,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
            };
            RenderOptions.SetBitmapScalingMode(logo, BitmapScalingMode.HighQuality);
            var logoBox = new Border { Background = Brushes.White, Padding = new Thickness(2), Child = logo, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetColumn(logoBox, 0);
            header.Children.Add(logoBox);

            var details = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(8,0,0,0) };
            details.Children.Add(new TextBlock { Text = "OPTIK LENTERA", FontSize = 19, FontWeight = FontWeights.Bold, Foreground = printMode ? Brushes.Black : Brush("#98752A"), Margin = new Thickness(0,0,0,2) });
            details.Children.Add(new TextBlock { Text = "Jl. Cibarengkok RT.03 RW.01 Peusar, Kec. Panongan, Kab. Tangerang", FontSize = 9, Foreground = printMode ? Brushes.Black : Brush("#51484A"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,2,0,0) });
            details.Children.Add(new TextBlock { Text = "Telp/WA: 0858 9312 8257", FontSize = 9, Foreground = printMode ? Brushes.Black : Brush("#51484A"), Margin = new Thickness(0,2,0,0) });
            Grid.SetColumn(details, 1);
            header.Children.Add(details);
            return new Border
            {
                BorderBrush = printMode ? Brushes.Black : Brush("#98752A"),
                BorderThickness = new Thickness(0,0,0,2),
                Padding = new Thickness(0,0,0,8),
                Child = header
            };
        }

        private StackPanel MakeDocumentContent(string heading, Order order, Payment payment, bool printMode)
        {
            var c = new StackPanel();
            c.Children.Add(MakeLetterhead(printMode));
            c.Children.Add(new TextBlock { Text = heading, FontSize = 19, FontWeight = FontWeights.Bold, Foreground = printMode ? Brushes.Black : Brush("#25241F"), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0,0,0,18) });
            c.Children.Add(new TextBlock { Text = payment == null ? "No. Invoice: INV-" + order.Date.Replace("-","") + "-" + order.OrderKey.Substring(0,Math.Min(6,order.OrderKey.Length)).ToUpperInvariant() : "No. Kuitansi: " + payment.ReceiptNumber, FontSize = 12, FontWeight = FontWeights.Bold });
            c.Children.Add(new TextBlock { Text = "Tanggal: " + (payment == null ? order.Date : payment.Date), FontSize = 11, Foreground = Brush("#69645B"), Margin = new Thickness(0,4,0,12) });
            c.Children.Add(new TextBlock { Text = "Pelanggan: " + order.CustomerName + "   |   WhatsApp: " + order.CustomerPhone, FontSize = 12, Margin = new Thickness(0,0,0,12) });
            c.Children.Add(new Border { Height = 1, Background = printMode ? Brushes.Black : Brush("#D8CBAE"), Margin = new Thickness(0,0,0,10) });
            c.Children.Add(new TextBlock { Text = "Frame: " + order.FrameDescription + "    Rp " + order.FramePrice.ToString("N0"), FontSize = 11, Margin = new Thickness(0,3,0,3) });
            c.Children.Add(new TextBlock { Text = "Lensa: " + order.LensDescription + "    Rp " + order.LensPrice.ToString("N0"), FontSize = 11, Margin = new Thickness(0,3,0,3) });
            if (order.OtherPrice > 0 || !string.IsNullOrWhiteSpace(order.OtherItem)) c.Children.Add(new TextBlock { Text = "Tambahan: " + order.OtherItem + "    Rp " + order.OtherPrice.ToString("N0"), FontSize = 11, Margin = new Thickness(0,3,0,3) });
            c.Children.Add(new Border { Height = 1, Background = printMode ? Brushes.Black : Brush("#D8CBAE"), Margin = new Thickness(0,10,0,10) });
            c.Children.Add(new TextBlock { Text = "TOTAL PESANAN: Rp " + order.Total.ToString("N0"), FontSize = 15, FontWeight = FontWeights.Bold, Foreground = printMode ? Brushes.Black : Brush("#A78342"), HorizontalAlignment = HorizontalAlignment.Right });
            if (payment != null)
            {
                var paid = PaidForOrder(order);
                c.Children.Add(new TextBlock { Text = "Pembayaran ini: Rp " + payment.Amount.ToString("N0") + " (" + payment.Method + ")", FontSize = 12, Margin = new Thickness(0,10,0,3) });
                c.Children.Add(new TextBlock { Text = "Total sudah dibayar: Rp " + paid.ToString("N0"), FontSize = 12, Margin = new Thickness(0,3,0,3) });
                c.Children.Add(new TextBlock { Text = "Sisa tagihan: Rp " + Math.Max(0,order.Total-paid).ToString("N0"), FontSize = 12, FontWeight = FontWeights.Bold, Margin = new Thickness(0,3,0,3) });
            }
            var documentNumber = payment == null ? "INV-" + order.Date.Replace("-","") + "-" + order.OrderKey.Substring(0,Math.Min(6,order.OrderKey.Length)).ToUpperInvariant() : payment.ReceiptNumber;
            var qrPayload = payment == null
                ? "OPTIK LENTERA | INVOICE | " + documentNumber + " | TANGGAL " + order.Date + " | PELANGGAN " + order.CustomerName + " | TOTAL " + order.Total.ToString("0") + " IDR"
                : "OPTIK LENTERA | KUITANSI | " + documentNumber + " | INVOICE " + "INV-" + order.Date.Replace("-","") + "-" + order.OrderKey.Substring(0,Math.Min(6,order.OrderKey.Length)).ToUpperInvariant() + " | TANGGAL " + payment.Date + " | DIBAYAR " + payment.Amount.ToString("0") + " IDR | SISA " + Math.Max(0,order.Total-PaidForOrder(order)).ToString("0") + " IDR";
            var qrSize = printMode ? 160.0 : 112.0;
            var qrImage = new Image { Source = CreateQrImage(qrPayload), Width = qrSize, Height = qrSize, Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0,4,0,0), SnapsToDevicePixels = true };
            if (printMode)
            {
                // Keep the QR code clean and unobstructed; any wet stamp is optional.
                var qrStack = new StackPanel { HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0,12,0,0) };
                qrStack.Children.Add(qrImage);
                qrStack.Children.Add(new TextBlock { Text = "Pindai ringkasan dokumen", FontSize = 8, Foreground = Brushes.Black, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0,2,0,0) });
                c.Children.Add(qrStack);
            }
            else
            {
                qrImage.HorizontalAlignment = HorizontalAlignment.Right;
                c.Children.Add(qrImage);
                c.Children.Add(new TextBlock { Text = "Pindai untuk membaca ringkasan dokumen", FontSize = 8, Foreground = Brush("#777168"), HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0,2,0,8) });
            }
            c.Children.Add(new TextBlock { Text = "Terima kasih telah mempercayakan kebutuhan penglihatan Anda kepada OPTIK LENTERA.", FontSize = 10, Foreground = Brush("#777168"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,8,0,0), HorizontalAlignment = HorizontalAlignment.Center });
            return c;
        }

        private ImageSource CreatePrintLogoSource()
        {
            // Use a clean white background while preserving the original logo colors.
            // Dark background pixels are replaced with white; gold/white logo details remain.
            var source = new BitmapImage(new Uri("pack://application:,,,/Assets/optik_lentera_app_logo.png", UriKind.Absolute));
            var converted = new FormatConvertedBitmap(source, PixelFormats.Bgra32, null, 0);
            converted.Freeze();
            int stride = converted.PixelWidth * 4;
            byte[] pixels = new byte[stride * converted.PixelHeight];
            converted.CopyPixels(pixels, stride, 0);
            for (int i = 0; i < pixels.Length; i += 4)
            {
                byte blue = pixels[i];
                byte green = pixels[i + 1];
                byte red = pixels[i + 2];
                byte alpha = pixels[i + 3];
                int luminance = (red * 299 + green * 587 + blue * 114) / 1000;
                if (alpha == 0 || luminance < 42)
                {
                    pixels[i] = 255;
                    pixels[i + 1] = 255;
                    pixels[i + 2] = 255;
                    pixels[i + 3] = 255;
                }
                else
                {
                    pixels[i + 3] = 255;
                }
            }
            var result = BitmapSource.Create(converted.PixelWidth, converted.PixelHeight, 96, 96, PixelFormats.Bgra32, null, pixels, stride);
            result.Freeze();
            return result;
        }

        private ImageSource CreateQrImage(string payload)
        {
            // Build QR as frozen WPF vector geometry, not a raster bitmap.
            // Legacy Epson/Windows 7 printer drivers can fail when PrintVisual
            // contains bitmap image sources. Vector modules keep the QR sharp
            // and preserve the original, proven WPF PrintVisual document layout.
            using (var generator = new QRCodeGenerator())
            using (var data = generator.CreateQrCode(payload, QRCodeGenerator.ECCLevel.M))
            {
                var modules = data.ModuleMatrix;
                int count = modules.Count;
                const double quiet = 4.0;
                const double moduleSize = 3.0;
                double extent = (count + quiet * 2) * moduleSize;

                var geometry = new GeometryGroup();
                for (int y = 0; y < count; y++)
                {
                    for (int x = 0; x < modules[y].Length; x++)
                    {
                        if (modules[y][x])
                        {
                            geometry.Children.Add(new RectangleGeometry(new Rect(
                                (x + quiet) * moduleSize,
                                (y + quiet) * moduleSize,
                                moduleSize,
                                moduleSize)));
                        }
                    }
                }

                var drawing = new DrawingGroup();
                drawing.Children.Add(new GeometryDrawing(Brushes.White, null,
                    new RectangleGeometry(new Rect(0, 0, extent, extent))));
                drawing.Children.Add(new GeometryDrawing(Brushes.Black, null, geometry));
                drawing.Freeze();

                var image = new DrawingImage(drawing);
                image.Freeze();
                return image;
            }
        }

        private void UpdateDocumentPreview()
        {
            if (documentPreview == null) return;
            var order = documentOrderBox == null ? null : documentOrderBox.SelectedItem as Order;
            var payment = documentPaymentBox == null ? null : documentPaymentBox.SelectedItem as Payment;
            if (order == null)
            {
                documentPreview.Child = new TextBlock { Text = "Belum ada pesanan. Buat pesanan terlebih dahulu.", Foreground = Brush("#777168") };
                if (documentStatus != null) documentStatus.Text = "Tidak ada data pesanan.";
                return;
            }
            try
            {
                documentPreview.Child = MakeDocumentContent(payment == null ? "INVOICE PESANAN" : "KUITANSI PEMBAYARAN", order, payment, false);
                if (documentStatus != null) documentStatus.Text = payment == null ? "Pratinjau invoice." : "Pratinjau kuitansi " + payment.ReceiptNumber + ".";
            }
            catch (Exception ex)
            {
                // Keep the invoice page usable even if preview rendering fails.
                documentPreview.Child = new TextBlock { Text = "Pratinjau dokumen belum dapat dibuat. Gunakan tombol cetak atau periksa data transaksi.\n" + ex.Message, Foreground = Brush("#9A5A42"), TextWrapping = TextWrapping.Wrap };
                if (documentStatus != null) documentStatus.Text = "Pratinjau mengalami kendala; halaman tetap bisa digunakan.";
            }
        }

        private void PrintInvoice_Click(object sender, RoutedEventArgs e)
        {
            var order = documentOrderBox == null ? null : documentOrderBox.SelectedItem as Order;
            if (order == null) { documentStatus.Text = "Pilih pesanan terlebih dahulu."; return; }
            PrintDocumentVisual(MakeDocumentContent("INVOICE PESANAN", order, null, true), "Invoice OPTIK LENTERA");
        }

        private void PrintReceipt_Click(object sender, RoutedEventArgs e)
        {
            var order = documentOrderBox == null ? null : documentOrderBox.SelectedItem as Order;
            var payment = documentPaymentBox == null ? null : documentPaymentBox.SelectedItem as Payment;
            if (order == null || payment == null) { documentStatus.Text = "Pilih pembayaran untuk mencetak kuitansi."; return; }
            PrintDocumentVisual(MakeDocumentContent("KUITANSI PEMBAYARAN", order, payment, true), "Kuitansi OPTIK LENTERA");
        }

        private void PrintExamination_Click(object sender, RoutedEventArgs e)
        {
            var exam = examGrid == null ? null : examGrid.SelectedItem as Examination;
            PrintSelectedExamination(exam);
        }

        private void PrintSelectedExamination_Click(object sender, RoutedEventArgs e)
        {
            var exam = documentExamBox == null ? null : documentExamBox.SelectedItem as Examination;
            PrintSelectedExamination(exam);
        }

        private void PrintSelectedExamination(Examination exam)
        {
            if (exam == null)
            {
                if (documentStatus != null) documentStatus.Text = "Pilih hasil pemeriksaan terlebih dahulu.";
                if (examStatus != null) examStatus.Text = "Pilih satu riwayat pemeriksaan terlebih dahulu.";
                return;
            }
            PrintDocumentVisual(MakePrescriptionContent(exam), "Resep OPTIK LENTERA");
        }

        private StackPanel MakePrescriptionContent(Examination exam)
        {
            var root = new StackPanel();
            root.Children.Add(MakeLetterhead(true));
            root.Children.Add(new TextBlock { Text = "RESEP KACAMATA", FontSize = 19, FontWeight = FontWeights.Bold, Foreground = Brushes.Black, TextAlignment = TextAlignment.Center, Margin = new Thickness(0,8,0,16) });
            var identity = new Grid { Margin = new Thickness(0,0,0,14) };
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.Children.Add(new TextBlock { Text = "Nama: " + exam.CustomerName, FontSize = 12, Foreground = Brush("#292823") });
            var date = new TextBlock { Text = "Tanggal: " + exam.Date, FontSize = 12, Foreground = Brush("#292823"), TextAlignment = TextAlignment.Right };
            Grid.SetColumn(date,1); identity.Children.Add(date); root.Children.Add(identity);
            root.Children.Add(new TextBlock { Text = "HASIL PEMERIKSAAN", FontSize = 11, FontWeight = FontWeights.Bold, Foreground = Brush("#A7833F"), Margin = new Thickness(0,0,0,7) });
            root.Children.Add(BuildCylinderAxisDiagram(exam.ODAXIS, exam.OSAXIS));
            var table = new Grid { Margin = new Thickness(0,0,0,12) };
            for (int i=0;i<6;i++) table.ColumnDefinitions.Add(new ColumnDefinition());
            for (int i=0;i<3;i++) table.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            string[][] values = new string[][] {
                new string[] { "MATA", "SPH", "CYL", "AXIS", "ADD", "PD" },
                new string[] { "OD • KANAN", exam.ODSPH, exam.ODCYL, exam.ODAXIS, exam.ODADD, exam.ODPD },
                new string[] { "OS • KIRI", exam.OSSPH, exam.OSCYL, exam.OSAXIS, exam.OSADD, exam.OSPD }
            };
            for (int r=0;r<3;r++) for (int col=0;col<6;col++)
            {
                var cell = new Border { BorderBrush = Brush("#D8D0C2"), BorderThickness = new Thickness(0,0,1,1), Padding = new Thickness(7,9,7,9), Background = r==0 ? Brush("#F2EBDD") : Brushes.White };
                cell.Child = new TextBlock { Text = values[r][col] ?? "", FontSize = 10, FontWeight = r==0 ? FontWeights.Bold : FontWeights.Normal, Foreground = Brush("#292823"), TextAlignment = col==0 ? TextAlignment.Left : TextAlignment.Center };
                Grid.SetRow(cell,r); Grid.SetColumn(cell,col); table.Children.Add(cell);
            }
            root.Children.Add(table);
            if (!string.IsNullOrWhiteSpace(exam.Notes))
            {
                root.Children.Add(new TextBlock { Text = "CATATAN", FontSize = 10, FontWeight = FontWeights.Bold, Foreground = Brush("#A7833F"), Margin = new Thickness(0,3,0,4) });
                root.Children.Add(new TextBlock { Text = exam.Notes, FontSize = 11, Foreground = Brush("#292823"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,0,0,18) });
            }
            root.Children.Add(new TextBlock { Text = "Terima kasih telah mempercayakan kebutuhan penglihatan Anda kepada OPTIK LENTERA.", FontSize = 9, Foreground = Brush("#777168"), TextAlignment = TextAlignment.Center, Margin = new Thickness(0,20,0,0) });
            return root;
        }

        private Border BuildCylinderAxisDiagram(string odAxis, string osAxis)
        {
            var panel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
            panel.Children.Add(BuildAxisDial("OD • KANAN", odAxis));
            panel.Children.Add(BuildAxisDial("OS • KIRI", osAxis));
            var outer = new StackPanel();
            outer.Children.Add(new TextBlock
            {
                Text = "DIAGRAM SUMBU SILINDER (AXIS)",
                FontSize = 10, FontWeight = FontWeights.Bold,
                Foreground = Brushes.Black, TextAlignment = TextAlignment.Center,
                Margin = new Thickness(0, 0, 0, 5)
            });
            outer.Children.Add(panel);
            return new Border
            {
                BorderBrush = Brushes.Black, BorderThickness = new Thickness(1),
                Padding = new Thickness(8), Margin = new Thickness(0, 0, 0, 12),
                Child = outer
            };
        }

        private Border BuildAxisDial(string eye, string axisText)
        {
            double axis;
            bool hasAxis = double.TryParse(axisText, out axis);
            var canvas = new Canvas { Width = 126, Height = 112, Background = Brushes.White };
            const double cx = 63, cy = 54, radius = 43;
            canvas.Children.Add(new Ellipse
            {
                Width = radius * 2, Height = radius * 2,
                Stroke = Brushes.Black, StrokeThickness = 1,
                Fill = Brushes.White
            });
            Canvas.SetLeft(canvas.Children[0], cx - radius);
            Canvas.SetTop(canvas.Children[0], cy - radius);

            for (int degree = 0; degree < 180; degree += 15)
            {
                double angle = degree * Math.PI / 180.0;
                double dx = Math.Cos(angle) * radius;
                double dy = Math.Sin(angle) * radius;
                canvas.Children.Add(new Line
                {
                    X1 = cx - dx, Y1 = cy - dy, X2 = cx + dx, Y2 = cy + dy,
                    Stroke = Brushes.Black, StrokeThickness = degree % 30 == 0 ? 0.8 : 0.45,
                    Opacity = degree % 30 == 0 ? 0.8 : 0.45
                });
            }

            if (hasAxis && axis >= 0 && axis <= 180)
            {
                double angle = axis * Math.PI / 180.0;
                double dx = Math.Cos(angle) * (radius + 3);
                double dy = Math.Sin(angle) * (radius + 3);
                canvas.Children.Add(new Line
                {
                    X1 = cx - dx, Y1 = cy - dy, X2 = cx + dx, Y2 = cy + dy,
                    Stroke = Brushes.Black, StrokeThickness = 2.5
                });
            }

            var label = new TextBlock
            {
                Text = eye + "    AXIS: " + (hasAxis ? axisText + "°" : "—"),
                FontSize = 9, FontWeight = FontWeights.Bold,
                Foreground = Brushes.Black, TextAlignment = TextAlignment.Center,
                Margin = new Thickness(0, 0, 0, 2)
            };
            var content = new StackPanel();
            content.Children.Add(label);
            content.Children.Add(canvas);
            return new Border
            {
                BorderBrush = Brushes.Black, BorderThickness = new Thickness(0.6),
                Margin = new Thickness(5, 0, 5, 0), Padding = new Thickness(3),
                Child = content
            };
        }

        private void PrintDocumentVisual(StackPanel content, string title)
        {
            try
            {
                // Preview uses only a detached bitmap. Printer objects and the
                // final print page are created only after explicit confirmation.
                const double formWidth = 14.0 * 96.0 / 2.54;
                const double formHeight = 24.0 * 96.0 / 2.54;

                var printable = new Border
                {
                    Background = Brushes.White,
                    Padding = new Thickness(12),
                    Width = 720,
                    Child = content
                };
                printable.Measure(new Size(720, double.PositiveInfinity));
                var measuredHeight = Math.Max(1, printable.DesiredSize.Height);
                printable.Arrange(new Rect(0, 0, 720, measuredHeight));
                printable.UpdateLayout();

                var previewBitmap = new RenderTargetBitmap(
                    (int)Math.Ceiling(formWidth), (int)Math.Ceiling(formHeight),
                    96, 96, PixelFormats.Pbgra32);
                var previewDrawing = new DrawingVisual();
                using (var dc = previewDrawing.RenderOpen())
                {
                    dc.DrawRectangle(Brushes.White, null, new Rect(0, 0, formWidth, formHeight));
                    double scale = Math.Min(formWidth / 720.0, formHeight / measuredHeight);
                    double drawnWidth = 720.0 * scale;
                    double drawnHeight = measuredHeight * scale;
                    dc.PushTransform(new TranslateTransform((formWidth - drawnWidth) / 2.0, 0));
                    dc.PushTransform(new ScaleTransform(scale, scale));
                    dc.DrawRectangle(new VisualBrush(printable), null, new Rect(0, 0, 720, measuredHeight));
                    dc.Pop();
                    dc.Pop();
                }
                previewBitmap.Render(previewDrawing);
                previewBitmap.Freeze();

                var previewImage = new Image
                {
                    Source = previewBitmap,
                    Stretch = Stretch.Uniform,
                    SnapsToDevicePixels = true
                };

                var previewWindow = new Window
                {
                    Title = "Pratinjau Cetak - " + title,
                    Width = 650,
                    Height = 820,
                    MinWidth = 520,
                    MinHeight = 650,
                    WindowStartupLocation = WindowStartupLocation.CenterOwner,
                    Owner = this,
                    Background = Brush("#F1EEE8"),
                    ResizeMode = ResizeMode.CanResize
                };

                bool continueToPrint = false;
                var layout = new DockPanel { Margin = new Thickness(14) };
                var toolbar = new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    HorizontalAlignment = HorizontalAlignment.Right,
                    Margin = new Thickness(0, 0, 0, 12)
                };
                var cancelButton = MakeActionButton("Batal");
                cancelButton.Margin = new Thickness(0, 0, 8, 0);
                cancelButton.Click += (s, e) => previewWindow.Close();
                var printButton = MakeActionButton("Lanjut ke Printer");
                printButton.Click += (s, e) => { continueToPrint = true; previewWindow.Close(); };
                toolbar.Children.Add(cancelButton);
                toolbar.Children.Add(printButton);
                DockPanel.SetDock(toolbar, Dock.Top);
                layout.Children.Add(toolbar);

                // A Viewbox fits the complete 14 x 24 cm sheet into the
                // available screen area: no long scrolling preview.
                var pageFrame = new Border
                {
                    Background = Brushes.White,
                    BorderBrush = Brush("#B9AD98"),
                    BorderThickness = new Thickness(1),
                    Padding = new Thickness(8),
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center,
                    Child = new Viewbox
                    {
                        Stretch = Stretch.Uniform,
                        Child = previewImage
                    }
                };
                layout.Children.Add(pageFrame);
                previewWindow.Content = layout;
                previewWindow.ShowDialog();

                if (!continueToPrint) return;

                // Only now create the WPF page and access the printer driver.
                var page = new Viewbox
                {
                    Width = formWidth,
                    Height = formHeight,
                    Stretch = Stretch.Uniform,
                    StretchDirection = StretchDirection.DownOnly,
                    Child = printable
                };
                page.Measure(new Size(formWidth, formHeight));
                page.Arrange(new Rect(0, 0, formWidth, formHeight));
                page.UpdateLayout();

                var dialog = new PrintDialog();
                if (dialog.ShowDialog() != true) return;

                var ticket = dialog.PrintTicket ?? new System.Printing.PrintTicket();
                ticket.PageMediaSize = new System.Printing.PageMediaSize(formWidth, formHeight);
                ticket.PageOrientation = System.Printing.PageOrientation.Portrait;
                dialog.PrintTicket = ticket;

                dialog.PrintVisual(page, title);
                if (documentStatus != null)
                    documentStatus.Text = "Dokumen dikirim ke printer setelah pratinjau.";
            }
            catch (Exception ex)
            {
                MessageBox.Show("Pratinjau atau pencetakan gagal: " + ex.Message, "OPTIK LENTERA",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }
}
}
