//
//  RVCtrlViewController.swift
//  RVRemocon
//
//  Created by 김선욱 on 10/2/25.
//


import UIKit

class RVMCtrlViewController: UIViewController {

    // MARK: - Bluetooth Singleton
    let btManager = BluetoothManager.shared

    // MARK: - UI Elements
    @IBOutlet weak var imgCaravan: UIImageView!

    @IBOutlet weak var btLFront: UIButton!
    @IBOutlet weak var btLBack: UIButton!
    @IBOutlet weak var btRFront: UIButton!
    @IBOutlet weak var btRBack: UIButton!
    @IBOutlet weak var btFront: UIButton!
    @IBOutlet weak var btBack: UIButton!
    @IBOutlet weak var btTurnCW: UIButton!
    @IBOutlet weak var btTurnCCW: UIButton!
    @IBOutlet weak var btStop: UIButton!

    @IBOutlet weak var btLActu: UIButton!
    @IBOutlet weak var btRActu: UIButton!

    @IBOutlet weak var btSpeed1: UIButton!
    @IBOutlet weak var btSpeed2: UIButton!
    @IBOutlet weak var btSpeed3: UIButton!
    @IBOutlet weak var btSpeed4: UIButton!

    @IBOutlet weak var autoActu: UIStackView!
    @IBOutlet weak var autoActuCheck: UISwitch!
    private var iRVMModel = 0
    // MARK: - Internal Variables
    var degreeL = 5
    var degreeR = 5
    var actuMove = 5
    var actuMoveStop = 5
    var actuCnt = 0

    var clickPosL: CGFloat = 0
    var clickPosR: CGFloat = 0
    var clickPosX: CGFloat = 0

    var distL: CGFloat = 0
    var distR: CGFloat = 0
    var distX: CGFloat = 0

    var speedMax = 4

    var controlModeJOY = true
    var controlModeAct = true
    var motionStopPressed = false
    let STOP_MESSAGE_SENDNUM = 10
    var motionCmdStopCnt = 0

    var timer: Timer?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadConfig()
        setupButtons()
//        setJOGControlMode()
//        setHiddenActuator()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
        onActionStop()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }

    // MARK: - Timer
    func startTimer() {
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                self.onActionCommand()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    @IBAction func toggleActu(_ sender: UIButton) {
        if sender.currentImage == UIImage(named: "actu_down") {
            sender.setImage(UIImage(named: "actu_up"), for: .normal)
        } else {
            sender.setImage(UIImage(named: "actu_down"), for: .normal)
        }
    }
    
    private func loadConfig() {
        // 저장된 SAL 모델 인덱스 불러오기
        let defaults = UserDefaults.standard
        iRVMModel = defaults.integer(forKey: "ConfRVMModel")
    }
    
    // MARK: - Button Setup
    func setupButtons() {
        btLFront.setImage(UIImage(named: "btLFront"), for: .normal)
        btLBack.setImage(UIImage(named: "btLBack"), for: .normal)
        btRFront.setImage(UIImage(named: "btRFront"), for: .normal)
        btRBack.setImage(UIImage(named: "btRBack"), for: .normal)
        btFront.setImage(UIImage(named: "btFront"), for: .normal)
        btBack.setImage(UIImage(named: "btBack"), for: .normal)
        
        btTurnCW.setImage(UIImage(named: "btTurn_cw"), for: .normal)
        btTurnCCW.setImage(UIImage(named: "btTurn_ccw"), for: .normal)
        
        btStop.setImage(UIImage(named: "stop"), for: .normal)
        btStop.setImage(UIImage(named: "stop2"), for: .highlighted)
        btLActu.setImage(UIImage(named: "actu_down"), for: .normal)
        btLActu.setImage(UIImage(named: "actu_down2"), for: .highlighted)

        btRActu.setImage(UIImage(named: "actu_up"), for: .normal)
        btRActu.setImage(UIImage(named: "actu_up2"), for: .highlighted)
        if iRVMModel != 1{
            btRActu.isHidden = true
            btLActu.isHidden = true
            autoActu.isHidden = true
        }
        
        let buttons: [UIButton] = [
            btLFront, btLBack, btRFront, btRBack,
            btFront, btBack, btTurnCW, btTurnCCW,
            btStop, btLActu, btRActu,
            btSpeed1, btSpeed2, btSpeed3, btSpeed4
        ]
        for btn in buttons {
            btn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
            btn.tag = 0 // false equivalent
        }
    }

    func setMoveCommand() {
        if btTurnCW.tag == 1 {
            degreeL = 5 + speedMax  // Max 9
            degreeR = 5 - speedMax  // Min 1
        } else if btTurnCCW.tag == 1 {
            degreeL = 5 - speedMax
            degreeR = 5 + speedMax
        } else if btFront.tag == 1 {
            degreeL = 5 + speedMax
            degreeR = 5 + speedMax
            if btLFront.tag == 1 { degreeR = 5 }
            if btRFront.tag == 1 { degreeL = 5 }
        } else if btBack.tag == 1 {
            degreeL = 5 - speedMax
            degreeR = 5 - speedMax
            if btLBack.tag == 1 { degreeR = 5 }
            if btRBack.tag == 1 { degreeL = 5 }
        } else {
            if btLFront.tag == 1 {
                degreeL = 5 + speedMax
            } else if btLBack.tag == 1 {
                degreeL = 5 - speedMax
            } else {
                degreeL = 5
            }

            if btRFront.tag == 1 {
                degreeR = 5 + speedMax
            } else if btRBack.tag == 1 {
                degreeR = 5 - speedMax
            } else {
                degreeR = 5
            }
        }
    }

    
    // MARK: - Button Actions
    @objc func buttonTouchDown(_ sender: UIButton) {
        var isPush = false

        switch sender {
        case btFront,btLFront,btRFront,btBack,btLBack,btRBack,btTurnCW, btTurnCCW:
//            handleJoyTouch(&clickPosL, &clickPosX)
            if actuCnt == 0 { sender.tag = 1; isPush = true }
//        case btRFront:
//            clickPosR = sender.frame.origin.y
        case btLActu:
            actuMove = autoActuCheck.isOn ? 9 : 8
            actuMoveStop = autoActuCheck.isOn ? 2 : 5
            actuCnt = 1
            isPush = true
        case btRActu:
            actuMove = autoActuCheck.isOn ? 1 : 2
            actuMoveStop = autoActuCheck.isOn ? 8 : 5
            actuCnt = 1
            isPush = true
        case btStop:
            motionStopPressed = true
            onActionStop()
            isPush = true
        case btSpeed1: setSpeedButton(1)
        case btSpeed2: setSpeedButton(2)
        case btSpeed3: setSpeedButton(3)
        case btSpeed4: setSpeedButton(4)
        default: break
        }
        

        if isPush { vibrateDevice(5) }
        setMoveCommand()
        setCaravanMotion()
        motionCmdStopCnt = STOP_MESSAGE_SENDNUM
    }

    @objc func buttonTouchUp(_ sender: UIButton) {
        switch sender {
        case btFront,btLFront,btRFront,btBack,btLBack,btRBack,btTurnCW, btTurnCCW:
            sender.tag = 0
//        case btLFront, btLBack:
//            if controlModeJOY {
//                degreeL = 5
//                sender.setBackgroundImage(UIImage(named: "jog_center"), for: .normal)
//            } else {
//                sender.tag = 0
//            }
//        case btRFront, btRBack:
//            if controlModeJOY {
//                degreeR = 5
//                sender.setBackgroundImage(UIImage(named: "jog_center"), for: .normal)
//            } else {
//                sender.tag = 0
//            }
        case btLActu:
            actuMove = 5
            actuCnt = 0
        case btRActu:
            actuMove = 5
            actuCnt = 0
        case btStop:
            onActionStop()
        default: break
        }

        motionCmdStopCnt = STOP_MESSAGE_SENDNUM
        motionStopPressed = false
        setMoveCommand()
        setCaravanMotion()
    }

    func handleJoyTouch(_ clickPosVar: inout CGFloat, _ clickPosXVar: inout CGFloat) {
        if actuCnt != 0 { return }
        clickPosVar = 0 // 초기화
        clickPosXVar = 0
    }

    // MARK: - Speed / Mode
    func setSpeedButton(_ maxSpeed: Int) {
        speedMax = maxSpeed
        let images = ["speed_1d","speed_2d","speed_3d","speed_4d"]
        btSpeed1.setImage(UIImage(named: images[0]), for: .normal)
        btSpeed2.setImage(UIImage(named: images[1]), for: .normal)
        btSpeed3.setImage(UIImage(named: images[2]), for: .normal)
        btSpeed4.setImage(UIImage(named: images[3]), for: .normal)

        switch maxSpeed {
        case 1: btSpeed1.setImage(UIImage(named: "speed_1"), for: .normal)
        case 2: btSpeed2.setImage(UIImage(named: "speed_2"), for: .normal)
        case 3: btSpeed3.setImage(UIImage(named: "speed_3"), for: .normal)
        default: btSpeed4.setImage(UIImage(named: "speed_4"), for: .normal)
        }
    }

    func setJOGControlMode() {
        if controlModeJOY {
            btLBack.isHidden = true
            btRBack.isHidden = true
            btLFront.setBackgroundImage(UIImage(named: "jog_center"), for: .normal)
            btRFront.setBackgroundImage(UIImage(named: "jog_center"), for: .normal)
        } else {
            btLBack.isHidden = false
            btRBack.isHidden = false
            btLFront.setBackgroundImage(UIImage(named: "up_arrow_l"), for: .normal)
            btRFront.setBackgroundImage(UIImage(named: "up_arrow_r"), for: .normal)
        }
    }

    func setHiddenActuator() {
        btLActu.isHidden = !controlModeAct
        btRActu.isHidden = !controlModeAct
        autoActuCheck.isHidden = !controlModeAct
    }

    // MARK: - Caravan Motion
    func setCaravanMotion() {
        var iMove = 0
        var iDegree = 0

        if degreeL > 5 && degreeR > 5 { iMove = 50; iDegree = 0 }
        else if degreeL < 5 && degreeR < 5 { iMove = -50; iDegree = 0 }
        else if degreeL > 5 && degreeR < 5 { iMove = 0; iDegree = 30 }
        else if degreeL < 5 && degreeR > 5 { iMove = 0; iDegree = -30 }
        else if degreeL < 5 { iMove = -30; iDegree = -15 }
        else if degreeL > 5 { iMove = 30; iDegree = 15 }
        else if degreeR < 5 { iMove = -30; iDegree = 15 }
        else if degreeR > 5 { iMove = 30; iDegree = -15 }
        else { iMove = 0; iDegree = 0 }

        imgCaravan.transform = CGAffineTransform(translationX: 0, y: CGFloat(-iMove))
        imgCaravan.image = UIImage(named: "caravan_mini")?.rotated(by: CGFloat(iDegree))
    }

    // MARK: - Action Command
    func onActionCommand() {
        let cmd = "L\(degreeL)R\(degreeR)A\(actuMove)\r\n"
        if !motionStopPressed && motionCmdStopCnt > 0 {
            btManager.sendData(cmd.data(using: .utf8)!)
        } else if actuMove == 1 || actuMove == 9 {
            actuMove = 5
            actuMoveStop = 5
        }

        if actuMove != 2 && actuMove != 8 && degreeL == 5 && degreeR == 5 && motionCmdStopCnt > 0 {
            motionCmdStopCnt -= 1
        }
    }

    func onActionStop() {
        degreeL = 5
        degreeR = 5
        actuMove = 5
        actuCnt = 0

//        btLFront.setBackgroundImage(UIImage(named: "jog_center"), for: .normal)
//        btRFront.setBackgroundImage(UIImage(named: "jog_center"), for: .normal)
//        btLActu.setBackgroundImage(UIImage(named: "actu_down"), for: .normal)
//        btRActu.setBackgroundImage(UIImage(named: "actu_up"), for: .normal)

        setCaravanMotion()

        if actuMoveStop != 5 {
            let s = "L\(degreeL)R\(degreeR)A\(actuMoveStop)\r\n"
            btManager.sendData(s.data(using: .utf8)!)
            actuMoveStop = 5
        }

        let s = "L\(degreeL)R\(degreeR)A\(actuMove)\r\n"
        btManager.sendData(s.data(using: .utf8)!)
    }

    // MARK: - Vibrate
    func vibrateDevice(_ ms: Int) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

}

// MARK: - UIImage Extension for Rotation
extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: size.width/2, y: size.height/2)
        context.rotate(by: radians)
        self.draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return rotatedImage
    }
}
//
//// MARK: - Bluetooth Singleton
//class BluetoothSingleton: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
//    static let shared = BluetoothSingleton()
//    var centralManager: CBCentralManager!
//    var connectedPeripheral: CBPeripheral?
//
//    private override init() {
//        super.init()
//        centralManager = CBCentralManager(delegate: self, queue: nil)
//    }
//
//    func send(_ data: Data) {
//        guard let peripheral = connectedPeripheral else { return }
//        // TODO: writeValue to characteristic
//    }
//
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        // TODO: handle Bluetooth state
//    }
//}
