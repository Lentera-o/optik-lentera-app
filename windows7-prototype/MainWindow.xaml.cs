using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
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
        private ComboBox documentOrderBox, documentPaymentBox;
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
            Grid.SetColumn(paymentSearchBox, 1);
            header.Children.Add(paymentSearchBox);
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
            var actions = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0,8,0,12) };
            var ib = MakeActionButton("Cetak Invoice"); ib.Click += PrintInvoice_Click; actions.Children.Add(ib);
            var rb = MakeActionButton("Cetak Kuitansi"); rb.Margin = new Thickness(10,0,0,0); rb.Click += PrintReceipt_Click; actions.Children.Add(rb);
            documentStatus = new TextBlock { Text = "Pilih pesanan untuk melihat invoice.", FontSize = 11, Foreground = Brush("#777168"), VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12,0,0,0) };
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

        private StackPanel MakeDocumentContent(string heading, Order order, Payment payment)
        {
            var c = new StackPanel();
            var logo = new Image { Source = new BitmapImage(new Uri("pack://application:,,,/Assets/optik_lentera_app_logo.png", UriKind.Absolute)), Width = 142, Height = 76, Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Center };
            RenderOptions.SetBitmapScalingMode(logo, BitmapScalingMode.HighQuality);
            c.Children.Add(logo);
            c.Children.Add(new TextBlock { Text = "JELAS LIHATNYA, JELAS REJEKINYA", FontSize = 9, Foreground = Brush("#777168"), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0,2,0,14) });
            c.Children.Add(new TextBlock { Text = heading, FontSize = 19, FontWeight = FontWeights.Bold, Foreground = Brush("#25241F"), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0,0,0,18) });
            c.Children.Add(new TextBlock { Text = payment == null ? "No. Invoice: INV-" + order.Date.Replace("-","") + "-" + order.OrderKey.Substring(0,Math.Min(6,order.OrderKey.Length)).ToUpperInvariant() : "No. Kuitansi: " + payment.ReceiptNumber, FontSize = 12, FontWeight = FontWeights.Bold });
            c.Children.Add(new TextBlock { Text = "Tanggal: " + (payment == null ? order.Date : payment.Date), FontSize = 11, Foreground = Brush("#69645B"), Margin = new Thickness(0,4,0,12) });
            c.Children.Add(new TextBlock { Text = "Pelanggan: " + order.CustomerName + "   |   WhatsApp: " + order.CustomerPhone, FontSize = 12, Margin = new Thickness(0,0,0,12) });
            c.Children.Add(new Border { Height = 1, Background = Brush("#D8CBAE"), Margin = new Thickness(0,0,0,10) });
            c.Children.Add(new TextBlock { Text = "Frame: " + order.FrameDescription + "    Rp " + order.FramePrice.ToString("N0"), FontSize = 11, Margin = new Thickness(0,3,0,3) });
            c.Children.Add(new TextBlock { Text = "Lensa: " + order.LensDescription + "    Rp " + order.LensPrice.ToString("N0"), FontSize = 11, Margin = new Thickness(0,3,0,3) });
            if (order.OtherPrice > 0 || !string.IsNullOrWhiteSpace(order.OtherItem)) c.Children.Add(new TextBlock { Text = "Tambahan: " + order.OtherItem + "    Rp " + order.OtherPrice.ToString("N0"), FontSize = 11, Margin = new Thickness(0,3,0,3) });
            c.Children.Add(new Border { Height = 1, Background = Brush("#D8CBAE"), Margin = new Thickness(0,10,0,10) });
            c.Children.Add(new TextBlock { Text = "TOTAL PESANAN: Rp " + order.Total.ToString("N0"), FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brush("#A78342"), HorizontalAlignment = HorizontalAlignment.Right });
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
            var qrImage = new Image { Source = CreateQrImage(qrPayload), Width = 92, Height = 92, Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0,12,0,0) };
            c.Children.Add(qrImage);
            c.Children.Add(new TextBlock { Text = "Pindai untuk membaca ringkasan dokumen", FontSize = 8, Foreground = Brush("#777168"), HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0,2,0,8) });
            c.Children.Add(new TextBlock { Text = "Terima kasih telah mempercayakan kebutuhan penglihatan Anda kepada OPTIK LENTERA.", FontSize = 10, Foreground = Brush("#777168"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,8,0,0), HorizontalAlignment = HorizontalAlignment.Center });
            return c;
        }

        private BitmapImage CreateQrImage(string payload)
        {
            // PngByteQRCode avoids the GDI+ bitmap renderer, which can crash on some
            // Windows 7 machines when the invoice preview is first opened.
            using (var generator = new QRCodeGenerator())
            using (var data = generator.CreateQrCode(payload, QRCodeGenerator.ECCLevel.M))
            {
                var qr = new PngByteQRCode(data);
                byte[] png = qr.GetGraphic(5);
                using (var stream = new MemoryStream(png))
                {
                    var image = new BitmapImage();
                    image.BeginInit();
                    image.CacheOption = BitmapCacheOption.OnLoad;
                    image.StreamSource = stream;
                    image.EndInit();
                    image.Freeze();
                    return image;
                }
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
                documentPreview.Child = MakeDocumentContent(payment == null ? "INVOICE PESANAN" : "KUITANSI PEMBAYARAN", order, payment);
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
            PrintDocumentVisual(MakeDocumentContent("INVOICE PESANAN", order, null), "Invoice OPTIK LENTERA");
        }

        private void PrintReceipt_Click(object sender, RoutedEventArgs e)
        {
            var order = documentOrderBox == null ? null : documentOrderBox.SelectedItem as Order;
            var payment = documentPaymentBox == null ? null : documentPaymentBox.SelectedItem as Payment;
            if (order == null || payment == null) { documentStatus.Text = "Pilih pembayaran untuk mencetak kuitansi."; return; }
            PrintDocumentVisual(MakeDocumentContent("KUITANSI PEMBAYARAN", order, payment), "Kuitansi OPTIK LENTERA");
        }

        private void PrintExamination_Click(object sender, RoutedEventArgs e)
        {
            var exam = examGrid == null ? null : examGrid.SelectedItem as Examination;
            if (exam == null)
            {
                if (examStatus != null) examStatus.Text = "Pilih satu riwayat pemeriksaan terlebih dahulu.";
                return;
            }
            PrintDocumentVisual(MakePrescriptionContent(exam), "Resep OPTIK LENTERA");
        }

        private StackPanel MakePrescriptionContent(Examination exam)
        {
            var root = new StackPanel();
            var logo = new Image
            {
                Source = new BitmapImage(new Uri("pack://application:,,,/Assets/optik_lentera_app_logo.png")),
                Width = 142, Height = 76, Stretch = System.Windows.Media.Stretch.Uniform,
                HorizontalAlignment = HorizontalAlignment.Center
            };
            RenderOptions.SetBitmapScalingMode(logo, BitmapScalingMode.HighQuality);
            root.Children.Add(logo);
            root.Children.Add(new TextBlock { Text = "RESEP KACAMATA", FontSize = 19, FontWeight = FontWeights.Bold, Foreground = Brush("#20211F"), TextAlignment = TextAlignment.Center, Margin = new Thickness(0,8,0,3) });
            root.Children.Add(new TextBlock { Text = "OPTIK LENTERA", FontSize = 10, FontWeight = FontWeights.SemiBold, Foreground = Brush("#A7833F"), TextAlignment = TextAlignment.Center, Margin = new Thickness(0,0,0,16) });
            var identity = new Grid { Margin = new Thickness(0,0,0,14) };
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.ColumnDefinitions.Add(new ColumnDefinition());
            identity.Children.Add(new TextBlock { Text = "Nama: " + exam.CustomerName, FontSize = 12, Foreground = Brush("#292823") });
            var date = new TextBlock { Text = "Tanggal: " + exam.Date, FontSize = 12, Foreground = Brush("#292823"), TextAlignment = TextAlignment.Right };
            Grid.SetColumn(date,1); identity.Children.Add(date); root.Children.Add(identity);
            root.Children.Add(new TextBlock { Text = "HASIL PEMERIKSAAN", FontSize = 11, FontWeight = FontWeights.Bold, Foreground = Brush("#A7833F"), Margin = new Thickness(0,0,0,7) });
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

        private void PrintDocumentVisual(StackPanel content, string title)
        {
            try
            {
                var printable = new Border { Background = Brushes.White, Padding = new Thickness(35), Width = 720, Child = content };
                printable.Measure(new Size(720, 1000));
                double pageHeight = Math.Max(900, printable.DesiredSize.Height);
                printable.Arrange(new Rect(0, 0, 720, pageHeight));

                // Print through a FixedDocument paginator instead of PrintVisual.
                // This avoids handing a live WPF visual directly to older Windows 7
                // printer drivers, which can terminate the process during printing.
                var fixedPage = new FixedPage { Width = 720, Height = pageHeight };
                fixedPage.Children.Add(printable);
                FixedPage.SetLeft(printable, 0);
                FixedPage.SetTop(printable, 0);
                fixedPage.Measure(new Size(720, pageHeight));
                fixedPage.Arrange(new Rect(0, 0, 720, pageHeight));
                fixedPage.UpdateLayout();

                var pageContent = new PageContent();
                ((IAddChild)pageContent).AddChild(fixedPage);
                var fixedDocument = new FixedDocument();
                fixedDocument.Pages.Add(pageContent);

                var dialog = new PrintDialog();
                if (dialog.ShowDialog() == true)
                {
                    dialog.PrintDocument(fixedDocument.DocumentPaginator, title);
                    if (documentStatus != null) documentStatus.Text = "Dokumen dikirim ke printer.";
                }
            }
            catch (Exception ex)
            {
                if (documentStatus != null)
                    documentStatus.Text = "Gagal mengirim dokumen ke printer: " + ex.Message;
                MessageBox.Show("Dokumen belum berhasil dicetak. Periksa printer dan driver, lalu coba lagi.\\n\\n" + ex.Message,
                    "Cetak OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private void BuildReportPage()
        {
            LoadOrders(); LoadPayments();
            var root = new StackPanel();
            var panel = MakePanel();
            var st = new StackPanel();
            var sales = orders.Sum(o => o.Total);
            var paid = payments.Sum(p => p.Amount);
            var due = orders.Sum(o => Math.Max(0,o.Total-PaidForOrder(o)));
            st.Children.Add(new TextBlock { Text = "RINGKASAN USAHA", FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Brush("#292823"), Margin = new Thickness(0,0,0,14) });
            st.Children.Add(new TextBlock { Text = "Jumlah pesanan: " + orders.Count, FontSize = 13, Margin = new Thickness(0,4,0,4) });
            st.Children.Add(new TextBlock { Text = "Nilai seluruh pesanan: Rp " + sales.ToString("N0"), FontSize = 13, Margin = new Thickness(0,4,0,4) });
            st.Children.Add(new TextBlock { Text = "Pembayaran diterima: Rp " + paid.ToString("N0"), FontSize = 13, Margin = new Thickness(0,4,0,4) });
            st.Children.Add(new TextBlock { Text = "Sisa tagihan: Rp " + due.ToString("N0"), FontSize = 13, FontWeight = FontWeights.Bold, Foreground = Brush("#A78342"), Margin = new Thickness(0,4,0,4) });
            panel.Child = st; root.Children.Add(panel);
            var list = MakePanel(); list.Margin = new Thickness(0,14,0,0);
            var grid = new DataGrid { AutoGenerateColumns = false, IsReadOnly = true, CanUserAddRows = false, HeadersVisibility = DataGridHeadersVisibility.Column, RowHeaderWidth = 0, Height = 320, ItemsSource = orders, Background = Brushes.White, BorderBrush = Brush("#ECE6DA"), BorderThickness = new Thickness(1) };
            grid.Columns.Add(new DataGridTextColumn { Header = "Tanggal", Binding = new System.Windows.Data.Binding("Date"), Width = 110 });
            grid.Columns.Add(new DataGridTextColumn { Header = "Pelanggan", Binding = new System.Windows.Data.Binding("CustomerName"), Width = new DataGridLength(1,DataGridLengthUnitType.Star) });
            grid.Columns.Add(new DataGridTextColumn { Header = "Total", Binding = new System.Windows.Data.Binding("TotalDisplay"), Width = 130 });
            list.Child = grid; root.Children.Add(list);
            DashboardContent.Children.Add(root);
        }

        private TextBlock BalanceValue(Grid grid, string caption, string value, int column)
        {
            var panel = new StackPanel { Margin = new Thickness(column == 0 ? 0 : 12,0,0,0) };
            panel.Children.Add(new TextBlock { Text = caption, Foreground = Brush("#C8A45D"), FontSize = 10, FontWeight = FontWeights.Bold });
            var result = new TextBlock { Text = value, Foreground = Brush("#F7F3EA"), FontSize = 18, FontWeight = FontWeights.Bold, Margin = new Thickness(0,4,0,0) };
            panel.Children.Add(result);
            Grid.SetColumn(panel, column);
            grid.Children.Add(panel);
            return result;
        }

        private void PaymentOrder_Changed(object sender, SelectionChangedEventArgs e) { UpdatePaymentBalance(); }

        private decimal PaidForOrder(Order order)
        {
            if (order == null) return 0;
            return payments.Where(p => p.OrderKey == order.OrderKey).Sum(p => p.Amount);
        }

        private void UpdatePaymentBalance()
        {
            if (paymentTotalText == null) return;
            var order = paymentOrderBox == null ? null : paymentOrderBox.SelectedItem as Order;
            var total = order == null ? 0 : order.Total;
            var paid = PaidForOrder(order);
            paymentTotalText.Text = "Rp " + total.ToString("N0");
            paymentPaidText.Text = "Rp " + paid.ToString("N0");
            paymentRemainingText.Text = "Rp " + Math.Max(0, total - paid).ToString("N0");
        }

        private void AddPayment_Click(object sender, RoutedEventArgs e)
        {
            var order = paymentOrderBox == null ? null : paymentOrderBox.SelectedItem as Order;
            if (order == null) { paymentStatus.Text = "Belum ada pesanan. Buat pesanan terlebih dahulu."; return; }
            var amount = ParsePrice(paymentAmountBox.Text);
            if (amount <= 0) { paymentStatus.Text = "Masukkan jumlah pembayaran yang valid."; return; }
            var remaining = order.Total - PaidForOrder(order);
            if (remaining <= 0) { paymentStatus.Text = "Pesanan ini sudah lunas."; return; }
            if (amount > remaining) { paymentStatus.Text = "Jumlah melebihi sisa tagihan Rp " + remaining.ToString("N0") + "."; return; }
            var record = new Payment {
                ReceiptNumber = "KWT-" + DateTime.Now.ToString("yyyyMMdd") + "-" + (payments.Count + 1).ToString("D4"),
                OrderKey = order.OrderKey, OrderDate = order.Date, CustomerName = order.CustomerName,
                CustomerPhone = order.CustomerPhone, Date = Read(paymentDateBox), Amount = amount,
                Method = paymentMethodBox.SelectedItem == null ? "Tunai" : paymentMethodBox.SelectedItem.ToString(),
                Notes = Read(paymentNotesBox), OrderTotal = order.Total
            };
            payments.Add(record);
            if (!SavePayments()) { payments.Remove(record); paymentStatus.Text = "Gagal menyimpan pembayaran. Data tidak ditambahkan."; return; }
            paymentAmountBox.Clear();
            paymentNotesBox.Clear();
            UpdatePaymentBalance();
            ApplyPaymentSearch();
            paymentStatus.Text = "Pembayaran tersimpan. No. kuitansi: " + record.ReceiptNumber;
        }

        private void SearchPayments_Changed(object sender, TextChangedEventArgs e) { ApplyPaymentSearch(); }

        private void ApplyPaymentSearch()
        {
            if (paymentGrid == null) return;
            var query = paymentSearchBox == null ? "" : (paymentSearchBox.Text ?? "").Trim();
            paymentGrid.ItemsSource = payments.Where(p => query.Length == 0 ||
                p.ReceiptNumber.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 ||
                p.CustomerName.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            if (paymentCount != null) paymentCount.Text = "RIWAYAT PEMBAYARAN  •  " + payments.Count + " transaksi";
        }

        private void LoadPayments()
        {
            payments.Clear();
            try { if (!File.Exists(paymentFile)) return; var loaded = new JavaScriptSerializer().Deserialize<List<Payment>>(File.ReadAllText(paymentFile)); if (loaded != null) foreach (var item in loaded) payments.Add(item); }
            catch { MessageBox.Show("Data pembayaran lokal belum dapat dibaca. File tidak dihapus.", "OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Warning); }
        }

        private bool SavePayments()
        {
            try
            {
                var folder = Path.GetDirectoryName(paymentFile);
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
                File.WriteAllText(paymentFile, new JavaScriptSerializer().Serialize(payments.ToList()));
                return true;
            }
            catch (Exception ex) { MessageBox.Show("Pembayaran gagal disimpan: " + ex.Message, "OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Error); return false; }
        }

        private Grid MakeInputGrid()
        {
            var grid = new Grid { Margin = new Thickness(0,0,0,3) };
            for (int i = 0; i < 3; i++) grid.ColumnDefinitions.Add(new ColumnDefinition());
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            return grid;
        }

        private TextBlock SectionCaption(string text)
        {
            return new TextBlock { Text = text, FontSize = 11, FontWeight = FontWeights.Bold, Foreground = Brush("#A78342"), Margin = new Thickness(0,12,0,8) };
        }

        private decimal ParsePrice(string value)
        {
            decimal result;
            var cleaned = (value ?? "").Replace("Rp", "").Replace(".", "").Replace(",", "").Trim();
            return decimal.TryParse(cleaned, out result) && result > 0 ? result : 0;
        }

        private void OrderPrice_Changed(object sender, TextChangedEventArgs e) { UpdateOrderTotal(); }

        private void UpdateOrderTotal()
        {
            if (orderTotalText == null) return;
            var total = ParsePrice(framePriceBox == null ? "" : framePriceBox.Text) +
                        ParsePrice(lensPriceBox == null ? "" : lensPriceBox.Text) +
                        ParsePrice(otherPriceBox == null ? "" : otherPriceBox.Text);
            orderTotalText.Text = "Rp " + total.ToString("N0");
        }

        private void AddOrder_Click(object sender, RoutedEventArgs e)
        {
            var customer = orderCustomerBox == null ? null : orderCustomerBox.SelectedItem as Customer;
            if (customer == null) { orderStatus.Text = "Pilih pelanggan terlebih dahulu. Tambahkan di menu Pelanggan jika belum ada."; return; }
            var framePrice = ParsePrice(framePriceBox.Text);
            var lensPrice = ParsePrice(lensPriceBox.Text);
            var otherPrice = ParsePrice(otherPriceBox.Text);
            if (framePrice <= 0 || lensPrice <= 0) { orderStatus.Text = "Harga frame dan lensa wajib diisi."; return; }
            var record = new Order {
                OrderId = Guid.NewGuid().ToString("N"),
                Date = Read(orderDateBox), CustomerName = customer.Name, CustomerPhone = customer.Phone,
                FrameBrand = Read(frameBrandBox), FrameModel = Read(frameModelBox), FrameColor = Read(frameColorBox), FramePrice = framePrice,
                LensType = Read(lensTypeBox), LensSize = Read(lensSizeBox), LensCoating = Read(lensCoatingBox), LensPrice = lensPrice,
                OtherItem = Read(otherItemBox), OtherPrice = otherPrice, Notes = Read(orderNotesBox)
            };
            orders.Add(record);
            if (!SaveOrders()) { orders.Remove(record); orderStatus.Text = "Gagal menyimpan pesanan. Data belum ditambahkan."; return; }
            frameBrandBox.Clear(); frameModelBox.Clear(); frameColorBox.Clear(); framePriceBox.Clear();
            lensTypeBox.Clear(); lensSizeBox.Clear(); lensCoatingBox.Clear(); lensPriceBox.Clear();
            otherItemBox.Clear(); otherPriceBox.Clear(); orderNotesBox.Clear();
            ApplyOrderSearch();
            orderStatus.Text = "Pesanan berhasil disimpan secara lokal.";
        }

        private void SearchOrders_Changed(object sender, TextChangedEventArgs e) { ApplyOrderSearch(); }

        private void ApplyOrderSearch()
        {
            if (orderGrid == null) return;
            var query = orderSearchBox == null ? "" : (orderSearchBox.Text ?? "").Trim();
            orderGrid.ItemsSource = orders.Where(x => query.Length == 0 ||
                x.CustomerName.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 ||
                x.FrameDescription.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 ||
                x.LensDescription.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            if (orderCount != null) orderCount.Text = "DAFTAR PESANAN  •  " + orders.Count + " data";
        }

        private void LoadOrders()
        {
            orders.Clear();
            try { if (!File.Exists(orderFile)) return; var loaded = new JavaScriptSerializer().Deserialize<List<Order>>(File.ReadAllText(orderFile)); if (loaded != null) foreach (var item in loaded) orders.Add(item); }
            catch { MessageBox.Show("Data pesanan lokal belum dapat dibaca. File tidak dihapus.", "OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Warning); }
        }

        private bool SaveOrders()
        {
            try
            {
                var folder = Path.GetDirectoryName(orderFile);
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
                File.WriteAllText(orderFile, new JavaScriptSerializer().Serialize(orders.ToList()));
                return true;
            }
            catch (Exception ex) { MessageBox.Show("Pesanan gagal disimpan: " + ex.Message, "OPTIK LENTERA", MessageBoxButton.OK, MessageBoxImage.Error); return false; }
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
            var button = new Button
            {
                Content = caption,
                Padding = new Thickness(19,10,19,10),
                Background = Brush("#20211F"),
                Foreground = Brush("#E6C982"),
                BorderThickness = new Thickness(0),
                FontSize = 12,
                FontWeight = FontWeights.SemiBold,
                Cursor = System.Windows.Input.Cursors.Hand,
                FocusVisualStyle = null,
                HorizontalContentAlignment = HorizontalAlignment.Center,
                VerticalContentAlignment = VerticalAlignment.Center
            };
            var template = new ControlTemplate(typeof(Button));
            var border = new FrameworkElementFactory(typeof(Border));
            border.Name = "buttonBorder";
            border.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
            border.SetValue(Border.CornerRadiusProperty, new CornerRadius(9));
            border.SetValue(Border.PaddingProperty, new TemplateBindingExtension(Button.PaddingProperty));
            border.SetValue(Border.SnapsToDevicePixelsProperty, true);
            var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
            presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            presenter.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            presenter.SetValue(ContentPresenter.RecognizesAccessKeyProperty, true);
            border.AppendChild(presenter);
            template.VisualTree = border;
            var hover = new Trigger { Property = Button.IsMouseOverProperty, Value = true };
            hover.Setters.Add(new Setter(Border.BackgroundProperty, Brush("#3A3428"), "buttonBorder"));
            hover.Setters.Add(new Setter(Button.ForegroundProperty, Brushes.White));
            template.Triggers.Add(hover);
            var pressed = new Trigger { Property = Button.IsPressedProperty, Value = true };
            pressed.Setters.Add(new Setter(Border.BackgroundProperty, Brush("#A78342"), "buttonBorder"));
            pressed.Setters.Add(new Setter(Button.ForegroundProperty, Brushes.White));
            template.Triggers.Add(pressed);
            button.Template = template;
            return button;
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

        public class Order
        {
            public string OrderId { get; set; }
            public string PaymentLabel { get { return Date + " • " + CustomerName + " • Rp " + Total.ToString("N0"); } }
            public string Date { get; set; }
            public string CustomerName { get; set; }
            public string CustomerPhone { get; set; }
            public string FrameBrand { get; set; }
            public string FrameModel { get; set; }
            public string FrameColor { get; set; }
            public decimal FramePrice { get; set; }
            public string LensType { get; set; }
            public string LensSize { get; set; }
            public string LensCoating { get; set; }
            public decimal LensPrice { get; set; }
            public string OtherItem { get; set; }
            public decimal OtherPrice { get; set; }
            public string Notes { get; set; }
            public decimal Total { get { return FramePrice + LensPrice + OtherPrice; } }
            public string TotalDisplay { get { return "Rp " + Total.ToString("N0"); } }
            public string FrameDescription { get { return string.Join(" ", new[] { FrameBrand, FrameModel, FrameColor }.Where(v => !string.IsNullOrWhiteSpace(v))); } }
            public string OrderKey { get { return !string.IsNullOrWhiteSpace(OrderId) ? OrderId : Date + "|" + CustomerPhone + "|" + CustomerName + "|" + FrameBrand + "|" + FrameModel + "|" + Total.ToString(System.Globalization.CultureInfo.InvariantCulture); } }
            public string LensDescription { get { return string.Join(" ", new[] { LensType, LensSize, LensCoating }.Where(v => !string.IsNullOrWhiteSpace(v))); } }
        }

        public class Payment
        {
            public string ReceiptNumber { get; set; }
            public string OrderKey { get; set; }
            public string OrderDate { get; set; }
            public string CustomerName { get; set; }
            public string CustomerPhone { get; set; }
            public string Date { get; set; }
            public decimal Amount { get; set; }
            public string Method { get; set; }
            public string Notes { get; set; }
            public decimal OrderTotal { get; set; }
            public string AmountDisplay { get { return "Rp " + Amount.ToString("N0"); } }
        }

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