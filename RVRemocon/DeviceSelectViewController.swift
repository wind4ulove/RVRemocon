import UIKit
import CoreBluetooth

class DeviceSelectViewController: UIViewController, CBCentralManagerDelegate, UITableViewDelegate, UITableViewDataSource {

    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [CBPeripheral] = []
    private var pairedPeripheralUUID: String?
    private var pairedPeripheralName: String?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var autoConnectSwitch: UISwitch!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        tableView.delegate = self
        tableView.dataSource = self
        activityIndicator.hidesWhenStopped = true
        
        loadUserSettings()
        
        reloadButton.addTarget(self, action: #selector(reloadScan), for: .touchUpInside)
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        } else {
            print("블루투스를 켜주세요.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            tableView.reloadData()
        }
    }
    
    // MARK: - Scan
    @objc private func reloadScan() {
        discoveredPeripherals.removeAll()
        tableView.reloadData()
        startScan()
    }
    
    private func startScan() {
        activityIndicator.startAnimating()
        centralManager.stopScan()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.centralManager.stopScan()
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
        cell.detailTextLabel?.text = detail
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = discoveredPeripherals[indexPath.row]
        pairedPeripheralUUID = peripheral.identifier.uuidString
        pairedPeripheralName = peripheral.name ?? "알 수 없음"
        
        saveUserSettings()
        
        // 연결 시도
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    // MARK: - CBCentralManagerDelegate 연결 결과
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("연결됨: \(peripheral.name ?? "알 수 없음")")
        // 여기서 MainControlViewController 등으로 화면 전환
        let mainVC = MainControlViewController()
        navigationController?.pushViewController(mainVC, animated: true)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("연결 실패: \(error?.localizedDescription ?? "알 수 없음")")
    }
    
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
