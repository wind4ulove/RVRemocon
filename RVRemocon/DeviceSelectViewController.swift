import UIKit
import CoreBluetooth

class DeviceSelectViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private var discoveredPeripherals: [CBPeripheral] = []
    private var pairedPeripheralUUID: String?
    private var pairedPeripheralName: String?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var autoConnectSwitch: UISwitch!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private let btManager = BluetoothManager.shared
    @IBAction func backButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
        activityIndicator.hidesWhenStopped = true
        
        loadUserSettings()
        
        reloadButton.addTarget(self, action: #selector(reloadScan), for: .touchUpInside)
        
        
        // ✅ TableView 배경 투명하게 설정
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none

//        // ✅ 배경 이미지 설정 (선택사항)
//        let backgroundImageView = UIImageView(frame: view.bounds)
//        backgroundImageView.image = UIImage(named: "bg_600x1024") // 프로젝트에 추가한 이미지 이름
//        backgroundImageView.contentMode = .scaleAspectFill
//        tableView.backgroundView = backgroundImageView
        
        
        // 스캔 콜백
        btManager.onDiscover = { [weak self] peripheral, _ in
            guard let self = self else { return }
            // 이름이 없거나 빈 문자열이면 추가하지 않음
            guard let name = peripheral.name, !name.isEmpty else { return }
            // 중복 방지
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredPeripherals.append(peripheral)
                self.tableView.reloadData()
            }
        }
        
        // 연결 콜백
        btManager.onConnect = { [weak self] peripheral, error in
            guard let self = self else { return }
            if error == nil {
                print("연결됨: \(peripheral.name ?? "알 수 없음")")
//                self.navigateToMain()
                self.dismiss(animated: true, completion: nil)
            } else {
                print("연결 실패: \(error?.localizedDescription ?? "알 수 없음")")
            }
        }
        
        startScan()
    }
    
    // MARK: - Scan
    @objc private func reloadScan() {
        discoveredPeripherals.removeAll()
        tableView.reloadData()
        startScan()
    }
    
    private func startScan() {
        activityIndicator.startAnimating()
        discoveredPeripherals.removeAll()
        tableView.reloadData()
        
        btManager.startScan()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.btManager.stopScan()
            self.activityIndicator.stopAnimating()
            if self.discoveredPeripherals.isEmpty {
                print("검색된 블루투스 장치 없음")
            }
        }
    }
    
    // MARK: - UITableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredPeripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let peripheral = discoveredPeripherals[indexPath.row]
        
        let name = peripheral.name ?? "이름 없음"
        var detail = peripheral.identifier.uuidString
        
        if peripheral.identifier.uuidString == pairedPeripheralUUID {
            detail = "Default\n\(detail)"
        }
        
        cell.textLabel?.text = name
        cell.textLabel?.textColor = .black
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.textColor = .lightGray

        // ✅ 셀 배경 투명하게
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        return cell
    }

    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = discoveredPeripherals[indexPath.row]
        pairedPeripheralUUID = peripheral.identifier.uuidString
        pairedPeripheralName = peripheral.name ?? "알 수 없음"
        
        saveUserSettings()
        
        // BluetoothManager를 통해 연결
        btManager.connect(peripheral)
//        navigateToMain()
    }
    
//    // MARK: - 메인 화면 이동
//    private func navigateToMain() {
//        DispatchQueue.main.async {
//            let storyboard = UIStoryboard(name: "Main", bundle: nil)
//            if let mainVC = storyboard.instantiateViewController(withIdentifier: "MainControlViewController") as? MainControlViewController {
//                mainVC.modalPresentationStyle = .fullScreen
//                self.present(mainVC, animated: true)
//            }
//        }
//    }


    // MARK: - UserDefaults 저장/로드
    private func saveUserSettings() {
        let defaults = UserDefaults.standard
        defaults.set(pairedPeripheralUUID, forKey: "strConfDeviceAddr")
        defaults.set(pairedPeripheralName, forKey: "strConfDeviceName")
        defaults.set(autoConnectSwitch.isOn, forKey: "bConfAutoConnect")
    }
    
    private func loadUserSettings() {
        let defaults = UserDefaults.standard
        pairedPeripheralUUID = defaults.string(forKey: "strConfDeviceAddr")
        pairedPeripheralName = defaults.string(forKey: "strConfDeviceName")
        let autoConnect = defaults.bool(forKey: "bConfAutoConnect")
        autoConnectSwitch.isOn = autoConnect
    }
}
