import UIKit
import CoreBluetooth
import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource {

    var centralManager: CBCentralManager!
    var peripherals: [CBPeripheral] = []
    var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupTableView()
    }

    func setupTableView() {
        tableView = UITableView(frame: view.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
    }

    // MARK: BLE 스캔 시작
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("BLE 꺼져 있음")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        if !peripherals.contains(peripheral), let name = peripheral.name {
            peripherals.append(peripheral)
            print("발견됨: \(name)")
            tableView.reloadData()
        }
    }

    // MARK: 테이블뷰
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name
        cell.detailTextLabel?.text = peripheral.identifier.uuidString
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = peripherals[indexPath.row]
        centralManager.stopScan()
        selected.delegate = self
        centralManager.connect(selected, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ 연결됨: \(peripheral.name ?? "Unknown")")
        // 이후 Service 탐색 가능
        peripheral.discoverServices(nil)
    }
}
