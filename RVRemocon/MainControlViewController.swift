import UIKit

class MainControlViewController: UIViewController {

    // MARK: - IBOutlet
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    // MARK: - Child VCs
    private var rvmCtrlVC: RVMCtrlViewController!
    private var salCtrlVC: SALCtrlViewController!
    private var currentChildVC: UIViewController?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Child VC 초기화
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        rvmCtrlVC = storyboard.instantiateViewController(withIdentifier: "RVMCtrlViewController") as? RVMCtrlViewController
        salCtrlVC = storyboard.instantiateViewController(withIdentifier: "SALCtrlViewController") as? SALCtrlViewController

        setupChildVCs()
        switchToChild(index: 0) // 기본 화면: RVM
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
    // MARK: - Segment Control Action
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
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
