//
//  SALCtrlViewController.swift
//  RVRemocon
//
//  Created by 김선욱 on 10/2/25.
//


import UIKit

class SALCtrlViewController: UIViewController {
    // MARK: - Bluetooth Singleton
    let btManager = BluetoothManager.shared

    @IBOutlet weak var slopeFBLabel: UILabel!
    @IBOutlet weak var slopeLRLabel: UILabel!
//    @IBOutlet weak var voltageLabel: UILabel!
    
    @IBOutlet weak var sideImageView: UIImageView!
    @IBOutlet weak var backImageView: UIImageView!
     
    @IBOutlet weak var btLFront: UIButton!
    @IBOutlet weak var btLMiddle: UIButton!
    @IBOutlet weak var btLRear: UIButton!

    @IBOutlet weak var btRFront: UIButton!
    @IBOutlet weak var btRMiddle: UIButton!
    @IBOutlet weak var btRRear: UIButton!
    @IBOutlet weak var btUp: UIButton!
    @IBOutlet weak var btDown: UIButton!
    @IBOutlet weak var btAuto: UIButton!
//    @IBOutlet weak var btInit: UIButton!
//    @IBOutlet weak var btSetView: UIButton!
//    @IBOutlet weak var btParking: UIButton!
//    @IBOutlet weak var btGReset: UIButton!
    
    // MARK: - State Variables
//    private var FBAngle: CGFloat = 1.0
//    private var LRAngle: CGFloat = 0
    
    private var curLabels: [UILabel] = []
    private var maxLabels: [UILabel] = []
    
    private var frontButtons: [UIButton] = []
    private var middleButtons: [UIButton] = []
    private var rearButtons: [UIButton] = []
    private var buttonMap: [UIButton: String] = [:]
    
    private var iSALModel = 0
    private var isAutoFinish = false
    private var isMode4 = false
    private var mCmdSelect: UInt8 = 0x30  // '0'
    private var mCmdMotion: UInt8 = 0x50 // 'P'
    
    private var motionCmdStopCount = 0
    private let STOP_MESSAGE_SENDNUM = 10
    
    private var buttonStates: [ButtonType: Bool] = [:]
    
    private var timer: Timer?
    
    enum ButtonType {
        case gReset, initSetup, setView, parking
    }
    
    private var allButtons: [UIButton] = []
        
    // MARK: - 상태값
    private var bMiddle2RearMode = false
    private var levelerActMask: UInt8 = 0
        
        // 버튼 매핑: [UIButton: (on, off, act)]
    private var buttonMappings: [UIButton: (String, String, String)] = [:]
    private var buttonAutoMapping: (on: String, act: String, off: String) = ("", "", "")
 
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
//        setupUIArrays()
        
        loadConfig()
        setupButtons()
        buttonCheck()
        buttonAutoClear(false)
    }
    

    // MARK: - 버튼 매핑 및 초기화
    private func setupButtons() {
        frontButtons = [btLFront, btRFront]
        middleButtons = [btLMiddle, btRMiddle]
        rearButtons = [btLRear, btRRear]
        allButtons = frontButtons + middleButtons + rearButtons
        
        // 상태 초기화
        allButtons.forEach { $0.tag = 0 }
        btAuto.tag = 1
        btUp.tag = 0
        btDown.tag = 0
        
        // iSALModel 조건 처리
        if iSALModel == 2 { // SAL-CAR
            buttonMappings = [
                btLMiddle: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act"),
                btRMiddle: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act"),
                btLFront: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act"),
                btRFront: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act"),
                btLRear: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act"),
                btRRear: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act")
            ]
            btLMiddle.isHidden = true
            btRMiddle.isHidden = true
            bMiddle2RearMode = true
        } else {
            buttonMappings = [
                btLMiddle: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act"),
                btRMiddle: ("button_leveler_m_on", "button_leveler_m", "button_leveler_m_act"),
                btLFront: ("button_leveler_on", "button_leveler", "button_leveler_act"),
                btRFront: ("button_leveler_on", "button_leveler", "button_leveler_act"),
                btLRear: ("button_leveler_on", "button_leveler", "button_leveler_act"),
                btRRear: ("button_leveler_on", "button_leveler", "button_leveler_act")
            ]
            
            switch iSALModel {
            case 1: // SAL-Simple
                btLFront.isHidden = true
                btRFront.isHidden = true
                btLMiddle.isHidden = true
                btRMiddle.isHidden = true
                bMiddle2RearMode = true
            case 3: // SAL-BASIC
                btLMiddle.isHidden = true
                btRMiddle.isHidden = true
            default: break
            }
        }
        
        buttonAutoMapping = ("rautobutton_on", "rautobutton_act", "rautobutton")
        
        for btn in (frontButtons + middleButtons + rearButtons + [btUp, btDown, btAuto]).compactMap({ $0 }) {
            // 버튼 매핑 정보 가져오기
            if let mapping = buttonMappings[btn] {
                let offImageName = mapping.0    // (on, off, act) 중 'on' 상태
                btn.setImage(UIImage(named: offImageName), for: .normal)
            }
            btn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
//        
//        btAuto.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchUpInside)
        
        
        
        //        btInit.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
        //        btGReset.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
        //        btSetView.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
        //        btParking.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
    }
    
    // MARK: - Auto End / Start
    private func autoEnd(_ message: String) {
        btAuto.tag = 1
        btDown.tag = 0
        btUp.tag = 0
        print("Auto End: \(message)")
    }
    
    private func autoStart() {
        print("Auto Start")
    }
    
    // MARK: - 명령 확인
    private func checkCommand() {
        let selectedFront = frontButtons.filter { $0.tag == 1 }
        let selectedMiddle = middleButtons.filter { $0.tag == 1 }
        let selectedRear = rearButtons.filter { $0.tag == 1 }
        
        
        if selectedFront.count == 2 {
            mCmdSelect = 0x38   // '8'
        } else if selectedMiddle.count == 2 {
            mCmdSelect = 0x37   // '7'
        } else if selectedRear.count == 2 {
            mCmdSelect = bMiddle2RearMode ? 0x37 : 0x39
        } else {
            let all = middleButtons + frontButtons + rearButtons
            for (i, btn) in all.enumerated() where btn.tag == 1 {
                if bMiddle2RearMode && i > 3 {
                    mCmdSelect = UInt8(49 + (i % 2)) // '1' or '2'
                } else {
                    mCmdSelect = UInt8(49 + i)       // '1' ~ '6'
                }
                break
            }
        }
        
        // ✅ mCmdMotion 설정
        if btUp.tag == 1 {
            mCmdMotion = UInt8(ascii: "U")
        } else if btDown.tag == 1 {
            mCmdMotion = UInt8(ascii: "D")
        } else {
            mCmdMotion = UInt8(ascii: "P")
        }

        // ✅ Auto 상태 유지
        if mCmdMotion == UInt8(ascii: "P"), btAuto.tag != 0 {
            btAuto.tag = 1
        }

        
        print("CMD_SELECT: \(mCmdSelect), CMD_MOTION: \(mCmdSelect)")
    }
    
    // MARK: - 버튼 상태 초기화
    private func selectClear(_ selectedButton: UIButton) {
        if !frontButtons.contains(selectedButton) {
            frontButtons.forEach { $0.tag = 0 }
        }else{
            // front 그룹의 다른 버튼이 모두 tag == 0인지 확인
            let otherFrontButtons = frontButtons.filter { $0 != selectedButton }
            let otherHasActive = otherFrontButtons.contains { $0.tag == 1 }
            if otherHasActive && selectedButton.tag == 1 {frontButtons.forEach { $0.tag = 0 }}
        }
        if !middleButtons.contains(selectedButton) {
            middleButtons.forEach { $0.tag = 0 }
        }else{
            
            let otherButtons = middleButtons.filter { $0 != selectedButton }
            let otherHasActive = otherButtons.contains { $0.tag == 1 }
            if otherHasActive && selectedButton.tag == 1 {middleButtons.forEach { $0.tag = 0 }}
        }
        if !rearButtons.contains(selectedButton) {
            rearButtons.forEach { $0.tag = 0 }
        }else{
            
            let otherButtons = rearButtons.filter { $0 != selectedButton }
            let otherHasActive = otherButtons.contains { $0.tag == 1 }
            if otherHasActive && selectedButton.tag == 1 {rearButtons.forEach { $0.tag = 0 }}
        }
        selectedButton.tag = 1
        btAuto.tag = 0
        btUp.tag = 0
        btDown.tag = 0
        btAuto.setImage(UIImage(named: "rautobutton"), for: .normal)
    }
    
    // MARK: - 버튼 상태 표시
    private func buttonCheck() {
        var mtNo = 0
        if bMiddle2RearMode {
            levelerActMask |= (levelerActMask << 4)
            mtNo = 2
        }
        let buttons = [btLMiddle, btRMiddle, btLFront, btRFront, btLRear, btRRear]
        for i in mtNo..<buttons.count {
            let button = buttons[i]!
            let mapping = buttonMappings[button]!
            let onImage = UIImage(named: mapping.0)
            let offImage = UIImage(named: mapping.1)
            let actImage = UIImage(named: mapping.2)
            
            if (levelerActMask & (1 << i)) != 0 {
                button.setImage(actImage, for: .normal)
            } else if button.tag == 1 || btAuto.tag != 0 {
                button.setImage(onImage, for: .normal)
            } else {
                button.setImage(offImage, for: .normal)
            }
        }
        
//        if btAuto.tag == 1 {
//            btAuto.setBackgroundImage(UIImage(named: buttonAutoMapping.on), for: .normal)
//        } else if btAuto.tag != 0 {
//            btAuto.setBackgroundImage(UIImage(named: buttonAutoMapping.act), for: .normal)
//        } else {
//            btAuto.setBackgroundImage(UIImage(named: buttonAutoMapping.off), for: .normal)
//        }
        
        btUp.setImage(UIImage(named: btUp.tag == 1 ? "rbutton_up_on" : "rbutton_up"), for: .normal)
        btDown.setImage(UIImage(named: btDown.tag == 1 ? "rbutton_down_on" : "rbutton_down"), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - Setup
//    private func setupUIArrays() {
////        curLabels = [textCurLM, textCurRM, textCurLF, textCurRF, textCurLB, textCurRB]
////        maxLabels = [textMaxLM, textMaxRM, textMaxLF, textMaxRF, textMaxLB, textMaxRB]
//        
//        frontButtons = [btLFront, btRFront]
//        middleButtons = [btLMiddle, btRMiddle]
//        rearButtons = [btLRear, btRRear]
//        
//        for btn in frontButtons + middleButtons + rearButtons {
//            buttonMap[btn] = "0"
//            btn.tag = 0
//        }
//        
//        btAuto.tag = 1
//        btUp.tag = 0
//        btDown.tag = 0
////        btSetView.tag = 0
//    }
//    
    
    private func loadConfig() {
        // 저장된 SAL 모델 인덱스 불러오기
        let defaults = UserDefaults.standard
        iSALModel = defaults.integer(forKey: "ConfSALModel")
    }
    
    private func buttonAutoClear(_ isClear: Bool){
        btAuto.tag = isClear ? 0 : 1
        btUp.tag = 0
        btDown.tag = 0
        btAuto.setImage(UIImage(named: isClear ? "rautobutton" : "rautobutton_on"), for: .normal)
        for btn in (frontButtons + middleButtons + rearButtons).compactMap({ $0 }) {
            // 버튼 매핑 정보 가져오기
            if let mapping = buttonMappings[btn] {
                btn.setImage(UIImage(named: mapping.0), for: .normal)// (on, off, act) 중 'on' 상태
                btn.tag = 1
            }
        }

        if isClear {
            for btn in (middleButtons + rearButtons).compactMap({ $0 }) {
                // 버튼 매핑 정보 가져오기
                if let mapping = buttonMappings[btn] {
                    btn.setImage(UIImage(named: mapping.1), for: .normal)// (on, off, act) 중 'off' 상태
                    btn.tag = 0
                }
            }
        }

    }
    
    // MARK: - Button Actions
    @objc private func buttonTouchDown(_ sender: UIButton) {
        
        switch sender {
        case btUp:
            btUp.tag = 1
            btDown.tag = 0
//            btAuto.tag = 2
        case btDown :
            btDown.tag = 1
            btUp.tag = 0
//            btAuto.tag = -2
        case btAuto :
            buttonAutoClear(btAuto.tag==1)
        case btLFront,  btLRear, btRFront,  btRRear, btLMiddle, btRMiddle:
            selectClear(sender)
        default:
//            clearSelection(for: sender)
            sender.tag = 1
        }
        
        motionCmdStopCount = STOP_MESSAGE_SENDNUM
        buttonCheck()
        checkCommand()
        sendActionCommand()
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        if sender == btUp || sender == btDown {
            btUp.tag = 0
            btDown.tag = 0
        }
        motionCmdStopCount = STOP_MESSAGE_SENDNUM
        sendActionCommand()
    }

    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.sendActionCommand()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func debugPrint(_ data: Data){
        let asciiRange: ClosedRange<UInt8> = 0x20...0x7E  // 가시적 ASCII 범위 (스페이스~'~')

        // 변환
        let debugString = data.map { byte -> String in
            if asciiRange.contains(byte) {
                // 출력 가능한 ASCII 문자는 그대로
                return String(UnicodeScalar(byte))
            } else {
                // 그 외는 16진수로
                return String(format: "[%02X]", byte)
            }
        }.joined()

        print("Debug:", debugString)
    }
    
    // MARK: - Command Handling
    private func sendActionCommand() {
        let isOneSend = false
   
        // 예: 명령어 데이터 생성
        let data = Data([
            UInt8(ascii: "S"),
            mCmdSelect,
            UInt8(ascii: "C"),
            mCmdMotion,
            UInt8(ascii: "M"),
            (mCmdSelect &+ mCmdMotion) & 0xFF, // 체크섬 계산 // &+ 연산자는 오버플로우를 허용하는 덧셈
            13, // CR
            10  // LF
        ])

        
        if motionCmdStopCount > 0 || isOneSend {
            btManager.sendData(data)
            
            debugPrint(data)        // for Debug
            
            if isOneSend {
                motionCmdStopCount = 0
                mCmdSelect = 0x30
                mCmdMotion = 0x50
            }
        }
        
        if mCmdMotion == 0x50 && motionCmdStopCount > 0 {
            motionCmdStopCount -= 1
        }
        
        updateCaravanMotion()
    }
    
    private func mode4Change(_ setMode4: Bool) -> Data {
        isMode4 = setMode4
//        voltageLabel.text = setMode4 ? "전문가모드 ON" : ""
        return Data([UInt8(ascii: "$"), setMode4 ? 0x34 : 0x30])
    }
    
    private func updateCaravanMotion() {
        // 이미지 회전
        guard let parentVC = self.parent as? MainControlViewController else { return }      
        rotateSide(degree: parentVC.FBAngle)
        rotateBack(degree: parentVC.LRAngle)
        levelerActMask = parentVC.ActFlag
        buttonCheck()
    }

    private func rotateImage(_ image: UIImage, degree: CGFloat) -> UIImage {
        let radians = degree * .pi / 180
        let size = image.size
        
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        // 중앙 기준으로 회전
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: radians)

        // 원본 크기로 다시 그림
        image.draw(in: CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        ))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return rotatedImage
    }
    func rotateSide(degree: CGFloat) {
        let sideAngle = degree
        let radians = degree * .pi / 180
        UIView.animate(withDuration: 0.1) {
            self.sideImageView.transform = CGAffineTransform(rotationAngle: radians)
        }
        slopeFBLabel.text = String(format: "%.1f°", sideAngle)
    }

    func rotateBack(degree: CGFloat) {
        let backAngle = degree
        let radians = degree * .pi / 180
        UIView.animate(withDuration: 0.1) {
            self.backImageView.transform = CGAffineTransform(rotationAngle: radians)
        }
        slopeLRLabel.text = String(format: "%.1f°", backAngle)
    }

//
//    
//    @objc func handleAngleUpdate(_ notification: Notification) {
//        if let userInfo = notification.userInfo,
//           let fb = userInfo["fb"] as? CGFloat,
//           let lr = userInfo["lr"] as? CGFloat {
//               rotateSide(degree: fb)
//               rotateBack(degree: lr)
//           }
//    }

//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
}
