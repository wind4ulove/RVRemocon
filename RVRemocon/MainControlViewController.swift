import UIKit
import CoreBluetooth

class MainControlViewController: UIViewController {
    // MARK: - Bluetooth Singleton
    let btManager = BluetoothManager.shared
    
    // MARK: - IBOutlet
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    @IBOutlet weak var TopMenu: UIStackView!
    @IBOutlet weak var VoltageView: UILabel!
    // MARK: - Child VCs
    private var rvmCtrlVC: RVMCtrlViewController!
    private var salCtrlVC: SALCtrlViewController!
    private var currentChildVC: UIViewController?
    
    public var FBAngle: CGFloat = 0
    public var LRAngle: CGFloat = 0
    
    // MARK: - Loading Overlay
    private var loadingView: UIView?
    private var activityIndicator: UIActivityIndicatorView?
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
       
        initializeControllers()
        btManager.onDisconnect = { [weak self] peripheral, error in
            guard let self = self else { return }
            self.checkBluetoothConnection()
        }
            
        checkBluetoothConnection()
        showLoadingOverlay()
    }

    func parseReceivedData(_ str: String) {
        // 문자열을 ';' 기준으로 분리 (끝의 빈 값은 제거)
        let parts = str.split(separator: ";").map { String($0) }
        
        var voltageValue: Double?
        var frAngle: Float?
        var lrAngle: Float?
        
        for part in parts {
            if part.hasPrefix("VOL:") {
                // "VOL:" 뒤의 값을 Double로 변환
                let valueStr = part.replacingOccurrences(of: "VOL:", with: "")
                voltageValue = Double(valueStr)
            } else if part.hasPrefix("F") {
                // "F" 뒤의 값을 Int로 변환
                let valueStr = part.dropFirst()
                frAngle = Float(valueStr)
            } else if part.hasPrefix("L") {
                // "L" 뒤의 값을 Int로 변환
                let valueStr = part.dropFirst()
                lrAngle = Float(valueStr)
            }
        }
        
        // 파싱 결과 사용
        if let voltage = voltageValue {
//            print("Voltage:", voltage)
            updateVoltageLabel(voltage)  // 전압 라벨 업데이트 함수
        }
        if let fAngle = frAngle {
            self.FBAngle = CGFloat(fAngle*0.0054)
        }
        if let lAngle = lrAngle {
            self.LRAngle = CGFloat(lAngle*0.0054)
        }
    }

    private func updateVoltageLabel(_ voltage: Double) {
        var displayText = "Voltage : \(voltage)V"
        var displayColor = UIColor.label

        if voltage <= 10.0 {
            displayText += " (LOW)"
            displayColor = .red
        } else if voltage <= 12.0 {
            displayText += " (LOW)"
            displayColor = .orange
        }

        self.VoltageView.text = displayText
        self.VoltageView.textColor = displayColor
    }

    
    private func checkBluetoothConnection() {
        let defaults = UserDefaults.standard
        let targetUUID = UUID(uuidString: "AAA")
        guard let uuidString = defaults.string(forKey: "strConfDeviceAddr"),
              defaults.bool(forKey: "bConfAutoConnect"),
              let targetUUID = UUID(uuidString: uuidString)
        else {
            // 자동 연결 조건 불만족 → 장치 선택 화면
            showDeviceSelectScreen()
            return
        }
        showLoadingOverlay()
        
        var scanAttempts = 0
        let maxAttempts = 5
        let scanInterval: TimeInterval = 2.0

        func attemptScan() {
            scanAttempts += 1
            self.btManager.startScan()
            print("스캔 시작")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + scanInterval) {
                // UUID 문자열 비교 안전하게
                if let peripheral = self.btManager.discoveredPeripherals.first(where: { $0.identifier == targetUUID }) {
                    // 장치 발견 → 연결 시도
                    self.btManager.stopScan()
                    self.hideLoadingOverlay()
                    self.btManager.connect(peripheral)
                    
                    self.btManager.onReceiveData = { data in
                        if let str = String(data: data, encoding: .utf8) {
                            self.parseReceivedData(str)
                        }
                    }
                } else if scanAttempts < maxAttempts {
                    // 스캔 재시도
                    print("스캔 재시도")
                    attemptScan()
                } else {
                    // 장치 못 찾음
                    self.btManager.stopScan()
                    self.hideLoadingOverlay()
                    self.showDeviceNotFoundAlert()
                }
            }
        }

        attemptScan()
    }
    //viewWillAppear는 present()로 나갔다가 dismiss()로 돌아왔을 때 자동으로 다시 호출되는 생명주기 메서드
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // BluetoothManager 싱글톤 사용 중이라 가정
        if btManager.isConnected == false {
            print("⚠️ 블루투스 연결 안됨 — 재검색 시작")
            checkBluetoothConnection()
        } else {
            print("✅ 블루투스 연결됨 — 기존 연결 유지")
        }
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
    
    @IBAction func goToConfigView(_ sender: UIButton) {
        // "Config" → 이동할 스토리보드 이름 (ex. Config.storyboard)
        let storyboard = UIStoryboard(name: "Configuration", bundle: nil)
        
        // "ConfigViewController" → 스토리보드에서 설정한 ViewController의 Storyboard ID
        if let configVC = storyboard.instantiateViewController(withIdentifier: "ConfigViewController") as? ConfigViewController {
            configVC.modalPresentationStyle = .fullScreen   // 전체화면 전환 (선택사항)
            present(configVC, animated: true, completion: nil)
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
        alert.addAction(UIAlertAction(title: "재탐색", style: .cancel){
            _ in
            self.checkBluetoothConnection()
        })
        
        self.present(alert, animated: true)
    }

 
    private func checkBluetoothAndStart() {
        if btManager.state == .poweredOn {
            btManager.startScan()
        } else {
            print("⏳ Bluetooth 상태 대기 중...")
        }
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
//        guard let seg = segmentedControl else {
        guard let seg = TopMenu else {
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
    
//    func updateAngles(fb: CGFloat, lr: CGFloat) {
//        self.FBAngle = fb
//        self.LRAngle = lr
//
//        NotificationCenter.default.post(
//            name: NSNotification.Name("AngleUpdated"),
//            object: nil,
//            userInfo: ["fb": fb, "lr": lr]
//        )
//    }

}
