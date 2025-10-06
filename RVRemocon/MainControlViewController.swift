import UIKit

class MainControlViewController: UIViewController {
    
    // MARK: - UI Outlets
    @IBOutlet weak var imgCaravan: UIImageView!
    
    @IBOutlet weak var btLFront: UIButton!
    @IBOutlet weak var btLBack: UIButton!
    @IBOutlet weak var btRFront: UIButton!
    @IBOutlet weak var btRBack: UIButton!
    @IBOutlet weak var btFront: UIButton!
    @IBOutlet weak var btBack: UIButton!
    @IBOutlet weak var btTurnCW: UIButton!
    @IBOutlet weak var btTurnCCW: UIButton!
    
    @IBOutlet weak var btLActu: UIButton!
    @IBOutlet weak var btRActu: UIButton!
    @IBOutlet weak var btStop: UIButton!
    
    @IBOutlet weak var btSpeed1: UIButton!
    @IBOutlet weak var btSpeed2: UIButton!
    @IBOutlet weak var btSpeed3: UIButton!
    @IBOutlet weak var btSpeed4: UIButton!
    
    @IBOutlet weak var chkAutoActu: UISwitch!
    
    // MARK: - Variables
    weak var mainManager: MainCtrlManager?   // 안드로이드 MainCtrlActivity 대응
    var sendCount = 0
    
    var m_iDegreeL = 5
    var m_iDegreeR = 5
    var m_iActuaMove = 5
    var m_iActuaMoveStop = 5
    var m_iClickPosL = 0
    var m_iClickPosR = 0
    var m_iClickPosX = 0
    var m_iDistL = 0
    var m_iDistR = 0
    var m_iDistX = 0
    var m_iActuaCnt = 0
    
    var speedMax = 4
    var m_bControlModeJOY = true
    var m_bControlModeAct = true
    var m_bMotionStopPress = false
    
    static let STOP_MESSAGE_SENDNUM = 10
    var m_iMotionCmdStopCnt = 0
    
    var mTimer: Timer?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        chkAutoActu.isOn = true
        clearButtonTag()
        setSpeedButton(speedMax)
        setJOGControlMode()
        setHiddenActuator()
        
        setButtonListeners()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadConfig()
        startTimer()
        onActionStop()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    // MARK: - Timer
    func startTimer() {
        if mTimer == nil {
            mTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self] _ in
                self?.onActionCommand()
            })
        }
    }
    
    func stopTimer() {
        mTimer?.invalidate()
        mTimer = nil
    }
    
    // MARK: - Core Methods
    func sendData(_ data: Data) {
        guard let mainManager = mainManager, mainManager.isConnected else { return }
        mainManager.write(data)
    }
    
    func clearButtonTag() {
        btFront.isSelected = false
        btBack.isSelected = false
        btLFront.isSelected = false
        btLBack.isSelected = false
        btRFront.isSelected = false
        btRBack.isSelected = false
        btTurnCW.isSelected = false
        btTurnCCW.isSelected = false
    }
    
    func loadConfig() {
        guard let mgr = mainManager else { return }
        m_bControlModeJOY = mgr.m_bControlModeJOY
        m_bControlModeAct = mgr.m_bControlModeAct
    }
    
    func onActionCommand() {
        let s = "L\(m_iDegreeL)R\(m_iDegreeR)A\(m_iActuaMove)\r\n"
        if !m_bMotionStopPress && m_iMotionCmdStopCnt > 0 {
            sendData(Data(s.utf8))
        } else if m_iActuaMove == 1 || m_iActuaMove == 9 {
            m_iActuaMove = 5
            m_iActuaMoveStop = 5
        }
        
        if m_iActuaMove != 2 && m_iActuaMove != 8 && m_iDegreeL == 5 && m_iDegreeR == 5 && m_iMotionCmdStopCnt > 0 {
            m_iMotionCmdStopCnt -= 1
        }
    }
    
    func onActionStop() {
        m_iActuaMove = 5
        m_iDegreeL = 5
        m_iDegreeR = 5
        m_iActuaCnt = 0
        
        setCaravanMotion()
        
        if m_iActuaMoveStop != 5 {
            let s = "L\(m_iDegreeL)R\(m_iDegreeR)A\(m_iActuaMoveStop)\r\n"
            sendData(Data(s.utf8))
            m_iActuaMoveStop = 5
        }
        let s = "L\(m_iDegreeL)R\(m_iDegreeR)A\(m_iActuaMove)\r\n"
        sendData(Data(s.utf8))
    }
    
    func setSpeedButton(_ iMaxSpeed: Int) {
        speedMax = iMaxSpeed
        [btSpeed1, btSpeed2, btSpeed3, btSpeed4].forEach { $0?.isSelected = false }
        
        switch iMaxSpeed {
        case 1: btSpeed1.isSelected = true
        case 2: btSpeed2.isSelected = true
        case 3: btSpeed3.isSelected = true
        default: btSpeed4.isSelected = true
        }
    }
    
    func setJOGControlMode() {
        if m_bControlModeJOY {
            btLBack.isHidden = true
            btRBack.isHidden = true
            btLFront.setImage(UIImage(named: "jog_center"), for: .normal)
            btRFront.setImage(UIImage(named: "jog_center"), for: .normal)
        } else {
            btLBack.isHidden = false
            btRBack.isHidden = false
            btLFront.setImage(UIImage(named: "up_arrow_l"), for: .normal)
            btRFront.setImage(UIImage(named: "up_arrow_r"), for: .normal)
        }
    }
    
    func setHiddenActuator() {
        let hidden = !m_bControlModeAct
        chkAutoActu.isHidden = hidden
        btLActu.isHidden = hidden
        btRActu.isHidden = hidden
    }
    
    func setCaravanMotion() {
        var iMove = 0
        var iDegree = 0
        
        if m_iDegreeL > 5 && m_iDegreeR > 5 {
            iMove = 50
            iDegree = 0
        } else if m_iDegreeL < 5 && m_iDegreeR < 5 {
            iMove = -50
            iDegree = 0
        } else if m_iDegreeL > 5 && m_iDegreeR < 5 {
            iDegree = 30
        } else if m_iDegreeL < 5 && m_iDegreeR > 5 {
            iDegree = -30
        }
        
        if let caravan = UIImage(named: "caravan_mini") {
            imgCaravan.image = caravan.rotated(by: CGFloat(iDegree))
        }
    }
    
    // MARK: - Button Listeners
    func setButtonListeners() {
        let buttons: [UIButton] = [btLFront, btLBack, btRFront, btRBack,
                                   btFront, btBack, btLActu, btRActu,
                                   btTurnCW, btTurnCCW, btStop,
                                   btSpeed1, btSpeed2, btSpeed3, btSpeed4]
        
        buttons.forEach { btn in
            btn.addTarget(self, action: #selector(onButtonDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(onButtonUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
    }
    
    @objc func onButtonDown(_ sender: UIButton) {
        if !mainManager!.isConnected { return }
        
        if sender == btFront {
            sender.isSelected = true
        } else if sender == btBack {
            sender.isSelected = true
        } else if sender == btStop {
            m_bMotionStopPress = true
            onActionStop()
        }
        m_iMotionCmdStopCnt = MainControlViewController.STOP_MESSAGE_SENDNUM
        setCaravanMotion()
    }
    
    @objc func onButtonUp(_ sender: UIButton) {
        if sender == btFront || sender == btBack {
            sender.isSelected = false
        } else if sender == btStop {
            m_bMotionStopPress = false
            onActionStop()
        }
        m_iMotionCmdStopCnt = MainControlViewController.STOP_MESSAGE_SENDNUM
    }
}

// MARK: - UIImage Rotation Helper
extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        var newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        newSize.width = max(newSize.width, size.width)
        newSize.height = max(newSize.height, size.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.translateBy(x: newSize.width/2, y: newSize.height/2)
            ctx.rotate(by: radians)
            draw(in: CGRect(x: -size.width/2, y: -size.height/2,
                            width: size.width, height: size.height))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return newImage ?? self
        }
        return self
    }
}
