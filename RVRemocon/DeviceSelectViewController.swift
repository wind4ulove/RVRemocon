import UIKit
import CoreBluetooth

class DeviceSelectViewController: UIViewController {

    // UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let reloadButton = UIButton(type: .system)
    private let finishButton = UIButton(type: .system)
    private let autoConnectSwitch = UISwitch()
    private let autoConnectLabel = UILabel()
    private let activity = UIActivityIndicatorView(style: .large)

    // Data
    private var peripherals: [CBPeripheral] {
        return BluetoothManager.shared.discoveredPeripherals
    }

    // 저장 키
    private let savedDeviceKey = "savedDeviceUUID"
    private let autoConnectKey = "autoConnect"

    // 자동 연결 플래그
    private var autoConnectEnabled: Bool {
        get { return UserDefaults.standard.bool(forKey: autoConnectKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoConnectKey) }
    }

    private var savedDeviceUUID: String? {
        get { return UserDefaults.standard.string(forKey: savedDeviceKey) }
        set { UserDefaults.standard.set(newValue, forKey: savedDeviceKey) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Device Select"

        setupUI()
        setupCallbacks()
        updateAutoConnectUI()

        // Bluetooth 상태가 켜져 있으면 스캔 시작
        if BluetoothManager.shared.central.state == .poweredOn {
            startScanning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 뷰 등장 시 스캔 재개
        if BluetoothManager.shared.central.state == .poweredOn {
            startScanning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 화면 떠날 때 스캔 중지
        BluetoothManager.shared.stopScan()
    }

    private func setupUI() {
        // 테이블
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        // Reload button
        reloadButton.setTitle("재검색", for: .normal)
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(reloadButton)

        // Finish button
        finishButton.setTitle("종료", for: .normal)
        finishButton.addTarget(self, action: #selector(finishTapped), for: .touchUpInside)
        finishButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(finishButton)

        // Auto connect switch + label
        autoConnectLabel.text = "자동 연결"
        autoConnectLabel.translatesAutoresizingMaskIntoConstraints = false
        autoConnectSwitch.isOn = autoConnectEnabled
        autoConnectSwitch.addTarget(self, action: #selector(autoSwitchChanged), for: .valueChanged)
        autoConnectSwitch.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(autoConnectLabel)
        view.addSubview(autoConnectSwitch)

        // Activity
        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.hidesWhenStopped = true
        view.addSubview(activity)

        // Layout
        NSLayoutConstraint.activate([
            reloadButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            reloadButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            finishButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            finishButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            autoConnectLabel.leadingAnchor.constraint(equalTo: reloadButton.trailingAnchor, constant: 16),
            autoConnectLabel.centerYAnchor.constraint(equalTo: reloadButton.centerYAnchor),

            autoConnectSwitch.leadingAnchor.constraint(equalTo: autoConnectLabel.trailingAnchor, constant: 8),
            autoConnectSwitch.centerYAnchor.constraint(equalTo: autoConnectLabel.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: reloadButton.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupCallbacks() {
        // Bluetooth manager callbacks
        BluetoothManager.shared.onDiscover = { [weak self] peripheral, rssi in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
                // 자동 연결 체크
                if let saved = self?.savedDeviceUUID, peripheral.identifier.uuidString == saved, self?.autoConnectEnabled == true {
                    // 이미 연결 시도를 했는지 여부를 관리하려면 추가 플래그 필요
                    BluetoothManager.shared.connect(peripheral)
                }
            }
        }

        BluetoothManager.shared.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .poweredOn:
                    self?.startScanning()
                default:
                    self?.stopScanning()
                    // 토스트 대체: UIAlert
                    let alert = UIAlertController(title: "Bluetooth 필요", message: "블루투스가 켜져 있지 않습니다.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "확인", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }

        BluetoothManager.shared.onConnect = { [weak self] peripheral, error in
            DispatchQueue.main.async {
                self?.activity.stopAnimating()
                if let err = error {
                    let a = UIAlertController(title: "연결 실패", message: err.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "확인", style: .default))
                    self?.present(a, animated: true)
                } else {
                    // 성공하면 MainControl로 이동
                    self?.savedDeviceUUID = peripheral.identifier.uuidString
                    let vc = MainControlViewController()
                    vc.connectedPeripheral = peripheral
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }

        BluetoothManager.shared.onDisconnect = { [weak self] peripheral, error in
            DispatchQueue.main.async {
                let msg = error?.localizedDescription ?? "장치 연결이 끊어졌습니다."
                let a = UIAlertController(title: "연결 끊김", message: msg, preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "확인", style: .default))
                self?.present(a, animated: true)
            }
        }
    }

    private func updateAutoConnectUI() {
        autoConnectSwitch.isOn = autoConnectEnabled
    }

    @objc private func reloadTapped() {
        startScanning()
    }

    @objc private func finishTapped() {
        // 앱 종료(권장하지 않음) 대신 뷰 닫기
        navigationController?.popViewController(animated: true)
    }

    @objc private func autoSwitchChanged() {
        autoConnectEnabled = autoConnectSwitch.isOn
    }

    private func startScanning() {
        activity.startAnimating()
        BluetoothManager.shared.startScan()
        // 스캔을 너무 오래 하지 않도록 (예: 10초 후 자동 중지) — 필요하다면 타이머 추가
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    private func stopScanning() {
        activity.stopAnimating()
        BluetoothManager.shared.stopScan()
        tableView.reloadData()
    }
}

// MARK: - Table
extension DeviceSelectViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
         let count = peripherals.count
         return count == 0 ? 1 : count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // 디바이스가 없을 때 안내 문구
        if peripherals.count == 0 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "empty")
            cell.textLabel?.text = "블루투스 장치가 검색되지 않았습니다."
            cell.selectionStyle = .none
            return cell
        }

        let peripheral = peripherals[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let name = peripheral.name ?? "Unknown"
        var detail = peripheral.identifier.uuidString

        // 저장된 장치라면 표시
        if let saved = savedDeviceUUID, saved == peripheral.identifier.uuidString {
            detail += " (Saved)"
        }
        cell.textLabel?.text = name
        cell.detailTextLabel?.text = detail
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if peripherals.count == 0 {
            // 빈 항목 클릭 시 재검색
            startScanning()
            return
        }

        let peripheral = peripherals[indexPath.row]
        // 연결 시도
        activity.startAnimating()
        BluetoothManager.shared.connect(peripheral)
    }
}
