//
//  ConfigViewController.swift
//  RVRemocon
//
//  Created by 김선욱 on 10/10/25.
//


import UIKit

class ConfigViewController: UIViewController,UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var managerSwitch: UISwitch!

    @IBOutlet weak var controlModeSegment: UISegmentedControl! // Joy / Jog / Dir
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var rvmTableView: UITableView!
    @IBOutlet weak var salTableView: UITableView!
    
    // MARK: - 선택 상태
    var selectedRvmIndex: Int?
    var selectedSalIndex: Int?
    var setManagerMode: Bool = false
    var countManagermode: Int = 0
    
    // MARK: - 데이터
    let rvmOptions = ["None", "RV-9000AT", "RV-9000MT"]
    let salOptions = ["None", "SAL-SIMPLE", "SAL-CAR", "SAL-BASIC", "SAL-PREMIUM"]
    
    
    private var deviceAddress: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        // TableView 설정
        setupTableView(rvmTableView)
        setupTableView(salTableView)
        // RVM 테이블 선택 반영

        initUI()
    }
    // MARK: - TableView 초기 설정
    func setupTableView(_ tableView: UITableView) {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false  // StackView 안에서 스크롤 X
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.layoutIfNeeded() // contentSize 계산
        tableView.heightAnchor.constraint(equalToConstant: (44 * CGFloat(tableView == rvmTableView ? rvmOptions.count : salOptions.count))).isActive = true

        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .clear
    }
    @objc private func managerSwitchTouch() {
        setManagerMode = false // 관리자 모드 기본 Off
        if managerSwitch.isOn {
            // 알림 → 장치 선택 화면
            countManagermode += 1
            // 카운트가 3번까지는 안내 멘트가 노출되고 이후 안내 멘트가 없어짐.
            
            if countManagermode < 5 {
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "관리 모드 설정",
                        message: "장비 초기화 버튼이 노출됩니다.\n" +
                        "의도하지 않은 초기화 설정을 방지하기 위해 활성화 상태는 저장되지 않습니다.\n",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "확인", style: .default))
                    self.present(alert, animated: true)
                }
            }
            if countManagermode > 10 {
                let alert = UIAlertController(
                    title: "공장 관리 모드 설정",
                    message: "장비 공장 초기화 버튼이 노출됩니다.\n" +
                    "의도하지 않은 초기화 설정을 방지하기 위해 사용하지 않을 때는 설정을 꺼주세요.\n",
                    preferredStyle: .alert
                )
                alert.addTextField { textField in
                    textField.placeholder = "코드를 입력하세요"
                    textField.keyboardType = .numberPad
                    textField.isSecureTextEntry = true
                }

                alert.addAction(UIAlertAction(title: "취소", style: .cancel))
                alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
                    let input = alert.textFields?.first?.text ?? ""
//                    let requiredCode = "96120345" // 특수코드
                    let requiredCode = "96120" // 특수코드
                    if input == requiredCode {
                        self.setManagerMode = true // 관리자 모드 On
                        let ok = UIAlertController(title: "관리 모드 활성화",
                                                   message: "인증이 완료되었습니다.",
                                                   preferredStyle: .alert)
                        ok.addAction(UIAlertAction(title: "확인", style: .default))
                        self.present(ok, animated: true)
                    } else {
                        self.setManagerMode = false // 관리자 모드 Off
                        let fail = UIAlertController(title: "코드 오류",
                                                      message: "인증되지 않았습니다.",
                                                      preferredStyle: .alert)
                        fail.addAction(UIAlertAction(title: "확인", style: .default))
                        self.present(fail, animated: true)
                    }
                }))
                DispatchQueue.main.async {
                    self.present(alert, animated: true)
                }
                countManagermode = 0 //초기화
            }
        }
    }
    private func initUI() {
        // 전달된 값 받기
        if let name = UserDefaults.standard.string(forKey: "tempDeviceName") {
            deviceNameLabel.text = name
        }
        if let addr = UserDefaults.standard.string(forKey: "tempDeviceAddr") {
            deviceAddress = addr
        }
        managerSwitch.isOn = false
        managerSwitch.addTarget(self, action: #selector(managerSwitchTouch), for: .touchUpInside)
        loadUserSettings()
    }

    
    // MARK: - TableView DataSource
       func numberOfSections(in tableView: UITableView) -> Int { return 1 }

       func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
           switch tableView {
           case rvmTableView: return rvmOptions.count
           case salTableView: return salOptions.count
           default: return 0
           }
       }

    func tableView(_ tableView: UITableView,
                       cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RadioCell") ??
                       UITableViewCell(style: .default, reuseIdentifier: "RadioCell")

            switch tableView {
            case rvmTableView:
                cell.textLabel?.text = rvmOptions[indexPath.row]
                let selected = (selectedRvmIndex == indexPath.row)
                cell.accessoryType = selected ? .checkmark : .none
                cell.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.3) : .clear

            case salTableView:
                cell.textLabel?.text = salOptions[indexPath.row]
                let selected = (selectedSalIndex == indexPath.row)
                cell.accessoryType = selected ? .checkmark : .none
                cell.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.3) : .clear

            default: break
            }

            cell.selectionStyle = .none
            return cell
        }


    // MARK: - TableView Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView {
        case rvmTableView:
            selectedRvmIndex = indexPath.row
        case salTableView:
            selectedSalIndex = indexPath.row
        default: break
        }

        tableView.reloadData() // 체크마크 + 하이라이트 적용 위해 전체 reload
        printCurrentSelection()
    }

   // MARK: - 선택값 확인
   private func printCurrentSelection() {
       let rvm = selectedRvmIndex != nil ? rvmOptions[selectedRvmIndex!] : "None"
       let sal = selectedSalIndex != nil ? salOptions[selectedSalIndex!] : "None"

       print("✅ 선택 상태 -> RVM: \(rvm), SAL: \(sal)")
   }

    
    
    // MARK: - 저장 버튼
    @IBAction func submitTapped(_ sender: Any) {
        saveUserSettings()
        goToMainController()
    }

    // MARK: - 취소 버튼
    @IBAction func cancelTapped(_ sender: Any) {
        goToMainController()
    }

    // MARK: - 디바이스 변경
    @IBAction func deviceChangeTapped(_ sender: Any) {
        saveUserSettings()
        // DeviceSelectViewController로 이동
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "DeviceSelect", bundle: nil)
            if let deviceVC = storyboard.instantiateViewController(withIdentifier: "DeviceSelectViewController") as? DeviceSelectViewController {
                deviceVC.modalPresentationStyle = .fullScreen
                self.present(deviceVC, animated: true)
            }
        }
    }

    // MARK: - 설정 저장
    private func saveUserSettings() {
        let defaults = UserDefaults.standard

        defaults.set(deviceAddress, forKey: "strConfDevice")
//        defaults.set(autoConnectSwitch.isOn, forKey: "bConfAutoConnect")
        // RVM Model ("None", "RV-9000AT", "RV-9000MT"
        defaults.set(selectedRvmIndex, forKey: "ConfRVMModel")
        // SAL Model ("None", "SAL-SIMPLE", "SAL-CAR", "SAL-BASIC", "SAL-PREMIUM")
        defaults.set(selectedSalIndex, forKey: "ConfSALModel")
        // Control Mode (0=Joy, 1=Jog, 2=Dir)
        defaults.set(controlModeSegment.selectedSegmentIndex, forKey: "ConfControlMode")
        // Manager Mode (0=Normal, 1=Expert)
        if !managerSwitch.isOn {
            setManagerMode = false
        }
        defaults.set(setManagerMode, forKey: "ConfManagerMode")

    }

    // MARK: - 설정 불러오기
    private func loadUserSettings() {
        let defaults = UserDefaults.standard
        deviceNameLabel.text = defaults.string(forKey: "strConfDeviceName")
        
//        autoConnectSwitch.isOn = defaults.bool(forKey: "bConfAutoConnect")
        controlModeSegment.selectedSegmentIndex = defaults.integer(forKey: "ConfControlMode")
        selectedRvmIndex = defaults.integer(forKey: "ConfRVMModel")
        selectedSalIndex = defaults.integer(forKey: "ConfSALModel")
        setManagerMode = defaults.bool(forKey: "ConfManagerMode")
        
        rvmTableView.reloadData()
        salTableView.reloadData()
    }
    //viewWillAppear는 present()로 나갔다가 dismiss()로 돌아왔을 때 자동으로 다시 호출되는 생명주기 메서드
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        initUI()
    }
    private func goToMainController() {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let mainVC = storyboard.instantiateViewController(withIdentifier: "MainControlViewController") as? MainControlViewController {
                mainVC.modalPresentationStyle = .fullScreen
                mainVC.isManagerMode = self.managerSwitch.isOn
                self.present(mainVC, animated: true)
            }
        }
    }
}

