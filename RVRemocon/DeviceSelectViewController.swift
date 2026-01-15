import UIKit
import CoreBluetooth

class DeviceSelectViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private var discoveredPeripherals: [CBPeripheral] = []
    private var advertisementData: [UUID: [String: Any]] = [:]  // ⭐ 추가
    private var pairedPeripheralUUID: String?
    private var pairedPeripheralName: String?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    // MARK: - Loading Overlay
    private var loadingView: UIView?
    // 클래스 프로퍼티에 추가
    private var isConnecting = false
    // 클래스 프로퍼티에 추가
    private var isAppInactive = false
    
    private let btManager = BluetoothManager.shared
    @IBAction func backButtonTapped(_ sender: UIButton) {
        navigateToBack()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        btManager.disconnect()  // 연결을 해제하고 리스트를 표시.
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
        activityIndicator.hidesWhenStopped = true
        
        loadUserSettings()
        
        reloadButton.addTarget(self, action: #selector(reloadScan), for: .touchUpInside)
                
        // ✅ TableView 배경 투명하게 설정
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        btManager.onBluetoothPoweredOff = {
            self.btManager.presentBluetoothOffAlertIfNeeded(from: self)
        }

        // 스캔 콜백
        btManager.onDiscover = { [weak self] peripheral, advertisementData in
            guard let self = self else { return }

            // ⭐ Advertising Data에서 이름 추출
            let name = self.extractDeviceName(from: advertisementData, peripheral: peripheral)
            
            // ⭐ 이름이 없거나 "이름 없음"이면 무시
            guard !name.isEmpty && name != "이름 없음" else { return }
            
            // ⭐ Advertisement 데이터 저장
            self.advertisementData[peripheral.identifier] = advertisementData
            
            // 중복 방지
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredPeripherals.append(peripheral)
                self.tableView.reloadData()
            }
        }
        // 연결 콜백
        btManager.onConnect = { [weak self] peripheral, error in
            guard let self = self else { return }
            self.isConnecting = false
            hideLoadingOverlay()
            if error == nil {
                let name = self.pairedPeripheralName ?? "이름 없음"
                print("연결됨: \(name)")

                // 자동 이동을 조금 지연해서 페어링 팝업이 뜨는지(비활성 전환) 관찰
                let delay: TimeInterval = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // 대기 후에도 앱이 active라면 이전 화면으로 이동
                    if !self.isAppInactive {
                        self.navigateToBack()
                    } else {
                        // 앱이 inactive 상태면(페어링 팝업 가능성) 이동 취소
                        // 필요 시, 다시 active가 되었을 때 후속 동작을 하려면 appDidBecomeActive에서 처리
                        print("앱이 비활성 상태로 전환됨: 페어링 팝업 가능성 → 이동 취소")
                    }
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
            self.isConnecting = false
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
        btManager.onDisconnect = { [weak self] peripheral, error in
            guard let self = self else { return }
            self.isConnecting = false
            hideLoadingOverlay()
            // 저장값 제거
//            let defaults = UserDefaults.standard
//            defaults.removeObject(forKey: "strConfDeviceAddr")
//            DispatchQueue.main.async {
//                let alert = UIAlertController(
//                    title: "연결 실패",
//                    message: "디바이스가 연결을 거부하거나 연결 할 수 없습니다.\n",
//                    preferredStyle: .alert
//                )
//                alert.addAction(UIAlertAction(title: "확인", style: .default))
//                self.present(alert, animated: true)
//            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSceneActive),
            name: .sceneDidBecomeActive,
            object: nil
        )
        startScan()
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    @objc private func appWillResignActive() {
        isConnecting = true
        isAppInactive = true
        hideLoadingOverlay()
    }

    @objc private func appDidBecomeActive() {
        // 팝업이 사라졌거나 앱이 다시 전면으로 올라온 상태
        isAppInactive = false
        self.navigateToBack()
    }
    
    @objc private func onSceneActive() {
        guard isViewLoaded, view.window != nil else {
            print("Device VC가 표시되지 않음 → startScan 처리 스킵")
            return
        }
        startScan()
//        // 자동 이동을 조금 지연해서 페어링 팝업이 뜨는지(비활성 전환) 관찰
//        let delay: TimeInterval = 1.0
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//            // 대기 후에도 앱이 active라면 이전 화면으로 이동
//            if !self.isConnecting {
//                self.startScan()
//            } else {
//                // 앱이 inactive 상태면(페어링 팝업 가능성) 이동 취소
//                // 필요 시, 다시 active가 되었을 때 후속 동작을 하려면 appDidBecomeActive에서 처리
//                print("앱이 비활성 상태로 전환됨: 페어링 팝업 가능성 → 이동 취소")
//            }
//        }
    }
    
    // MARK: - Scan
    @objc private func reloadScan() {
//        discoveredPeripherals.removeAll()
//        tableView.reloadData()
        startScan()
    }
    
    private func startScan() {
        activityIndicator.startAnimating()
        discoveredPeripherals.removeAll()
        tableView.reloadData()
      
        if btManager.state != .poweredOn {
            self.btManager.presentBluetoothOffAlertIfNeeded(from: self)
            return
        }
        
        btManager.startScan()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.btManager.stopScan()
            self.activityIndicator.stopAnimating()
            if self.discoveredPeripherals.isEmpty {
                print("검색된 블루투스 장치 없음")
                self.tableView.reloadData() // 비어있을 때 메시지 행 표시
            }
        }
    }
    
    // MARK: - UITableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 장치가 없을 때도 1줄(메시지) 표시
        return max(discoveredPeripherals.count, 1)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)

        // 장치가 하나도 없을 때 메시지 셀 구성
        if discoveredPeripherals.isEmpty {
            cell.textLabel?.text = "검색된 블루투스 장치 없음"
            cell.textLabel?.textColor = .darkGray
            cell.detailTextLabel?.text = nil
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.selectionStyle = .none
            return cell
        }

        let peripheral = discoveredPeripherals[indexPath.row]

        // ⭐ Advertising Data에서 이름 가져오기
        let advData = advertisementData[peripheral.identifier] ?? [:]
        let name = extractDeviceName(from: advData, peripheral: peripheral)

        var detail = peripheral.identifier.uuidString

        if peripheral.identifier.uuidString == pairedPeripheralUUID {
            detail = "Default\n\(detail)"
        }

        cell.textLabel?.text = name
        cell.textLabel?.textColor = .black
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.textColor = .lightGray
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 선택 즉시 deselect
        tableView.deselectRow(at: indexPath, animated: true)

        let peripheral = discoveredPeripherals[indexPath.row]
        pairedPeripheralUUID = peripheral.identifier.uuidString

        let advData = self.advertisementData[peripheral.identifier] ?? [:]
        pairedPeripheralName = extractDeviceName(from: advData, peripheral: peripheral)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let title = (self.pairedPeripheralName ?? "") + "를 선택하셨습니다."
            let alert = UIAlertController(
                title: title,
                message: "디바이스에 연결하시겠습니까?\n",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
                // 확인을 눌렀을 때만 연결 시작
                self.isConnecting = true
                self.selectDeviceAndSave(peripheral: peripheral)
            }))
            self.present(alert, animated: true)
        }
    }
    
    func selectDeviceAndSave(peripheral: CBPeripheral? = nil) {
        showLoadingOverlay()

        guard let peripheral = peripheral else {
            // If no peripheral was provided, avoid a crash and inform the user
            hideLoadingOverlay()
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "연결할 디바이스가 없습니다",
                    message: "목록에서 디바이스를 선택한 후 다시 시도해 주세요.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(alert, animated: true)
            }
            return
        }
        saveUserSettings()
        // BluetoothManager를 통해 연결
        btManager.connect(peripheral, justCheckConnect: true)
    }

    @IBAction func goToConfigView(_ sender: UIButton) {
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
    
    // ⭐ Advertising Data에서 이름 추출 함수
    private func extractDeviceName(from advertisementData: [String: Any], peripheral: CBPeripheral) -> String {
        // 1. Complete Local Name (0x09)
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
            return localName
        }
        
        // 2. Shortened Local Name (fallback)
        if let shortName = advertisementData["kCBAdvDataLocalName"] as? String, !shortName.isEmpty {
            return shortName
        }
        
        // 3. peripheral.name (최후 수단 - 캐시된 값)
        return peripheral.name ?? "이름 없음"
    }
}
