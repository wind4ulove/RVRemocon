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
    // MARK: - Loading Overlay
    private var loadingView: UIView?
    
    private let btManager = BluetoothManager.shared
    @IBAction func backButtonTapped(_ sender: UIButton) {
        navigateToBack()
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
        
        btManager.disconnect()  // 연결을 해제하고 리스트를 표시.
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
        btManager.onSubscribe = { [weak self] peripheral, error in
            guard let self = self else { return }
            print("🔐 인증 완료, 완전 연결 상태")

            DispatchQueue.main.async {
                self.navigateToBack()
            }
        }
        // 연결 콜백
        btManager.onConnect = { [weak self] peripheral, error in
            guard let self = self else { return }
            hideLoadingOverlay()
            if error == nil {
                let name = peripheral.name ?? "이름 없음"
                print("연결됨: \(name)")
//
                DispatchQueue.main.async {
//                    self.navigateToBack()
                    let alert = UIAlertController(
                        title: "연결 이동",
                        message: "\(name)가 선택되었습니다.화면을 이동하시겠습니까?",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
                        self.navigateToBack()
                    }))
                    self.present(alert, animated: true)
                }
                
            } else {
                // 알림 → 장치 선택 화면
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "연결 실패",
                        message: "디바이스와의 연결에 실패 하였습니다.\n" +
                                    "설정 > Bluetooth에서 해당 기기를 제거 하거나\n다른 장치를 선택해 주세요.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "확인", style: .default))
                    self.present(alert, animated: true)
                }
                print("연결 실패: \(error?.localizedDescription ?? "알 수 없음")")
            }
        }
        btManager.onFailToConnect = { [weak self] peripheral, error in
            guard let self = self else { return }
            hideLoadingOverlay()
            // 저장값 제거
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "strConfDeviceAddr")
//            defaults.set(false, forKey: "bConfAutoConnect")

            // 알림 → 장치 선택 화면
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "페어링 정보 삭제됨",
                    message: "디바이스가 기존 페어링 정보를 삭제했습니다.\n" +
                            "설정 > Bluetooth에서 해당 기기를 제거 하거나\n다른 장치를 선택해 주세요.",
                                  
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "확인", style: .default))

                self.present(alert, animated: true)
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
        showLoadingOverlay()
        // BluetoothManager를 통해 연결
        btManager.connect(peripheral,justCheckConnect:true)
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
    @IBAction func goToConfigView(_ sender: UIButton) {
        // "Config" → 이동할 스토리보드 이름 (ex. Config.storyboard)
//        btManager.disconnect()  // 연결을 해제하고 리스트를 표시.
//        let storyboard = UIStoryboard(name: "Configuration", bundle: nil)
//        
//        // "ConfigViewController" → 스토리보드에서 설정한 ViewController의 Storyboard ID
//        if let configVC = storyboard.instantiateViewController(withIdentifier: "ConfigViewController") as? ConfigViewController {
//            configVC.modalPresentationStyle = .fullScreen   // 전체화면 전환 (선택사항)
//            present(configVC, animated: true, completion: nil)
//        }
        navigateToConfigView()
    }
    private func navigateToConfigView() {
        DispatchQueue.main.async {
            // "Config" → 이동할 스토리보드 이름 (ex. Config.storyboard)
            self.btManager.disconnect()  // 연결을 해제하고 리스트를 표시.
            let storyboard = UIStoryboard(name: "Configuration", bundle: nil)
            
            // "ConfigViewController" → 스토리보드에서 설정한 ViewController의 Storyboard ID
            if let configVC = storyboard.instantiateViewController(withIdentifier: "ConfigViewController") as? ConfigViewController {
                configVC.modalPresentationStyle = .fullScreen   // 전체화면 전환 (선택사항)
                self.present(configVC, animated: true, completion: nil)
            }
        }
    }
    private func navigateToBack() {
        DispatchQueue.main.async {
            self.btManager.disconnect()  // 연결을 해제하고 리스트를 표시.
            self.dismiss(animated: true, completion: nil)
        }
    }
    // MARK: - UserDefaults 저장/로드
    private func saveUserSettings() {
        let defaults = UserDefaults.standard
        defaults.set(pairedPeripheralUUID, forKey: "strConfDeviceAddr")
        defaults.set(pairedPeripheralName, forKey: "strConfDeviceName")
//        defaults.set(autoConnectSwitch.isOn, forKey: "bConfAutoConnect")
    }
    
    private func loadUserSettings() {
        let defaults = UserDefaults.standard
        pairedPeripheralUUID = defaults.string(forKey: "strConfDeviceAddr")
        pairedPeripheralName = defaults.string(forKey: "strConfDeviceName")
//        let autoConnect = defaults.bool(forKey: "bConfAutoConnect")
//        autoConnectSwitch.isOn = autoConnect
    }
    
    // MARK: - 로딩 오버레이
    private func showLoadingOverlay() {
        hideLoadingOverlay()
        
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.center = overlay.center
        spinner.startAnimating()

        overlay.addSubview(spinner)
        view.addSubview(overlay)

        loadingView = overlay
    }

    private func hideLoadingOverlay() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
}
