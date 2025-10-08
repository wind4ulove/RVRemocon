import UIKit
import CoreBluetooth

class MainControlViewController: UIViewController {

    // MARK: - IBOutlet
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    // MARK: - Child VCs
    private var rvmCtrlVC: RVMCtrlViewController!
    private var salCtrlVC: SALCtrlViewController!
    private var currentChildVC: UIViewController?
    
    // MARK: - Loading Overlay
    private var loadingView: UIView?
    private var activityIndicator: UIActivityIndicatorView?
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        checkBluetoothConnection()
        initializeControllers()
//        showLoadingOverlay()
//
//        setupBluetoothEvents()
//        checkBluetoothAndStart()
        showLoadingOverlay()
        

    }
    @IBAction func deviceSelectButtonTapped(_ sender: UIButton) {
        showDeviceSelectScreen()
    }

    private func checkBluetoothConnection() {
        let defaults = UserDefaults.standard
        
        guard let uuidString = defaults.string(forKey: "strConfDeviceAddr"),
              defaults.bool(forKey: "bConfAutoConnect"),
              let targetUUID = UUID(uuidString: uuidString)
        else {
            // 자동 연결 조건 불만족 → 장치 선택 화면
            showDeviceSelectScreen()
            return
        }
        
//        // 로딩 표시
//        showLoadingOverlay()
        
        var scanAttempts = 0
        let maxAttempts = 5
        let scanInterval: TimeInterval = 2.0

        func attemptScan() {
            scanAttempts += 1
            BluetoothManager.shared.startScan()
            print("스캔 시작")
            DispatchQueue.main.asyncAfter(deadline: .now() + scanInterval) {
                // UUID 문자열 비교 안전하게
                if let peripheral = BluetoothManager.shared.discoveredPeripherals.first(where: { $0.identifier == targetUUID }) {
                    // 장치 발견 → 연결 시도
                    BluetoothManager.shared.stopScan()
                    self.hideLoadingOverlay()
                    BluetoothManager.shared.connect(peripheral)
                    print("연결됨 \(targetUUID)")
                    BluetoothManager.shared.onReceiveData = { data in
                        if let str = String(data: data, encoding: .utf8) {
                            print("💬 수신:", str)
                        }
                    }
                } else if scanAttempts < maxAttempts {
                    // 스캔 재시도
                    print("스캔 재시도")
                    attemptScan()
                } else {
                    // 장치 못 찾음
                    BluetoothManager.shared.stopScan()
                    self.hideLoadingOverlay()
                    self.showDeviceNotFoundAlert()
                }
            }
        }

        attemptScan()
    }
    
    private func showDeviceSelectScreen() {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "DeviceSelect", bundle: nil)
            if let deviceVC = storyboard.instantiateViewController(withIdentifier: "DeviceSelectViewController") as? DeviceSelectViewController {
                deviceVC.modalPresentationStyle = .fullScreen
                self.present(deviceVC, animated: true)
            }
        }
    }

    private func showDeviceNotFoundAlert() {
        let alert = UIAlertController(
            title: "장치를 찾을 수 없습니다",
            message: "장치를 선택 화면에서 다시 선택하시겠습니까?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "선택 화면으로 이동", style: .default) { _ in
            self.showDeviceSelectScreen()
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel){
            _ in
            self.checkBluetoothConnection()
        })
        
        self.present(alert, animated: true)
    }
    
    
    // MARK: - Bluetooth 연결 처리
    private func setupBluetoothEvents() {
        let manager = BluetoothManager.shared

        manager.onStateChange = { [weak self] state in
            switch state {
            case .poweredOn:
                print("🔵 Bluetooth Powered On")
                manager.startScan()
            case .poweredOff:
                print("⚠️ Bluetooth Off")
                self?.showAlert("Bluetooth가 꺼져 있습니다.")
            default:
                print("ℹ️ Bluetooth state: \(state.rawValue)")
            }
        }

        manager.onDiscover = { peripheral, rssi in
            print("📡 발견됨: \(peripheral.name ?? "Unknown") RSSI:\(rssi)")
            // 여기서 원하는 장치 이름으로 필터링 가능
            if let name = peripheral.name, name.contains("RVController") {
                manager.stopScan()
                manager.connect(peripheral)
            }
        }

        manager.onConnect = { [weak self] peripheral, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert("연결 실패: \(error.localizedDescription)")
                    return
                }
                print("✅ 연결됨: \(peripheral.name ?? "Unknown")")
                self?.hideLoadingOverlay()
//                self?.initializeControllers()
            }
        }

        manager.onDisconnect = { [weak self] peripheral, _ in
            DispatchQueue.main.async {
                self?.showAlert("연결이 끊어졌습니다.")
                self?.showLoadingOverlay()
                manager.startScan()
            }
        }
    }

    private func checkBluetoothAndStart() {
        let manager = BluetoothManager.shared
        if manager.state == .poweredOn {
            manager.startScan()
        } else {
            print("⏳ Bluetooth 상태 대기 중...")
        }
    }
    // MARK: - 로딩 오버레이
    private func showLoadingOverlay() {
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

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    
    

    
    private func initializeControllers() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        rvmCtrlVC = storyboard.instantiateViewController(withIdentifier: "RVMCtrlViewController") as? RVMCtrlViewController
        salCtrlVC = storyboard.instantiateViewController(withIdentifier: "SALCtrlViewController") as? SALCtrlViewController

        setupChildVCs()
        switchToChild(index: 0)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateChildFrames()
    }

    // MARK: - Setup Child VCs
    private func setupChildVCs() {
        guard rvmCtrlVC != nil, salCtrlVC != nil else { return }

        // RVM 추가
        addChild(rvmCtrlVC)
        view.addSubview(rvmCtrlVC.view)
        rvmCtrlVC.didMove(toParent: self)

        // SAL 추가 (숨김)
        addChild(salCtrlVC)
        view.addSubview(salCtrlVC.view)
        salCtrlVC.didMove(toParent: self)
        salCtrlVC.view.isHidden = true

        currentChildVC = rvmCtrlVC
    }

    private func updateChildFrames() {
        let frame = childFrame()
        rvmCtrlVC?.view.frame = frame
        salCtrlVC?.view.frame = frame
    }

    private func childFrame() -> CGRect {
        guard let seg = segmentedControl else {
            print("segmentedControl is nil! Defaulting frame to full view")
            return view.bounds
        }

        return CGRect(
            x: 0,
            y: seg.frame.maxY,
            width: view.bounds.width,
            height: view.bounds.height - seg.frame.maxY
        )
    }
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        switchToChild(index: sender.selectedSegmentIndex)
    }


    private func switchToChild(index: Int) {
        guard let rvmVC = rvmCtrlVC, let salVC = salCtrlVC else { return }

        let newVC: UIViewController
        let oldVC = currentChildVC

        if index == 0 {
            newVC = rvmVC
            salVC.view.isHidden = true
        } else {
            newVC = salVC
            rvmVC.view.isHidden = true
        }

        newVC.view.isHidden = false
        currentChildVC = newVC

        // Optional: 애니메이션 전환
        UIView.transition(from: oldVC?.view ?? UIView(),
                          to: newVC.view,
                          duration: 0.25,
                          options: [.transitionCrossDissolve, .showHideTransitionViews],
                          completion: nil)
    }
}
