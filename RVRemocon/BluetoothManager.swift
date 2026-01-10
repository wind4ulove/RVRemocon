//
//  BluetoothManager.swift
//  RVRemocon
//
//  Created by 김선욱 on 10/2/25.
//


import Foundation
import CoreBluetooth
import UIKit

// 간단한 블루투스 매니저 싱글톤
final class BluetoothManager: NSObject{
    static let shared = BluetoothManager()
    
    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?
    
    private(set) var discoveredPeripherals: [CBPeripheral] = []
    /// PASSKEY / Bonding UI가 떠있는 중인지 여부
    private(set) var awaitingPairing = false
    // BluetoothManager 내부 프로퍼티에 추가
    private var isShowingBluetoothOffAlert = false
    
    var onDiscover: ((_ peripheral: CBPeripheral, _ rssi: NSNumber) -> Void)?
    var onStateChange: ((_ state: CBManagerState) -> Void)?
    var onConnect: ((_ peripheral: CBPeripheral, _ error: Error?) -> Void)?
    var onDisconnect: ((_ peripheral: CBPeripheral, _ error: Error?) -> Void)?
    var onFailToConnect: ((_ peripheral: CBPeripheral, _ error: Error?) -> Void)?
    var onReceiveData: ((Data) -> Void)?
    var onBluetoothPoweredOff: (() -> Void)?
    // MARK: - 자동 재연결
    private var targetPeripheralIdentifier: UUID?
    var isConnected: Bool {
        return connectedPeripheral?.state == .connected
    }
    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    // 외부에서 접근할 수 있는 읽기 전용 프로퍼티
    var state: CBManagerState {
        return central.state
    }

    // 스캔 시작
    func startScan() {
        guard central.state == .poweredOn else {
//            onBluetoothPoweredOff?()
            print("PowerOFF 상태입니다. 블루투스 기능을 켜주세요.")
            return
        }
        discoveredPeripherals.removeAll()
        // nil 서비스 -> 모든 광고 디바이스 스캔
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    // 스캔 중지
    func stopScan() {
        central.stopScan()
    }
    
    func connect(_ peripheral: CBPeripheral, justCheckConnect: Bool = false) {
//        targetPeripheralIdentifier = peripheral.identifier
        awaitingPairing = justCheckConnect
        
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil) // iOS가 자동으로 PASSKEY 요청
    }
    
    func disconnect() {
        awaitingPairing = true  // 재연결 방지
        
        if let peripheral = self.connectedPeripheral, self.isConnected {
            central.cancelPeripheralConnection(peripheral)
            print("🔌 Disconnected")
        } else {
            print("⚠️ 연결된 peripheral 없음")
        }

//        central.cancelPeripheralConnection(peripheral)
    }

    // 연결된(이미 연결된) peripheral 불러오기 (특정 서비스 UUID가 있을 때 유용)
    func retrieveConnectedPeripherals(withServices services: [CBUUID]) -> [CBPeripheral] {
        return central.retrieveConnectedPeripherals(withServices: services)
    }
    
    // MARK: - Send Data
    func sendData(_ data: Data) {
        guard let peripheral = connectedPeripheral else {
            print("❌ peripheral 없음")
            return
        }
        guard peripheral.state == .connected else {
            print("❌ peripheral 연결 안됨")
            return
        }
        guard let characteristic = writeCharacteristic else {
            print("❌ writeCharacteristic 없음 — characteristic이 아직 검색되지 않았을 수 있음")
            return
        }
        if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            print("📡 전송: \(String(data: data, encoding: .utf8) ?? data.description)")
        } else {
            print("❌ 쓰기 불가: 보호 특성, Passkey 미입력 가능")
        }
    }
    func send(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        self.sendData(data)
    }
    
    // MARK: - Notify 구독
    func subscribeToCharacteristic(_ characteristic: CBCharacteristic) {
        guard let peripheral = connectedPeripheral else { return }
        peripheral.setNotifyValue(true, for: characteristic)
        print("📡 Notify 구독 시작: \(characteristic.uuid)")
    }
    
    // MARK: - Helpers
    public func presentBluetoothOffAlertIfNeeded(from presenter: UIViewController? = nil, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.main.async {
            // 전역 플래그로 1차 차단
            if self.isShowingBluetoothOffAlert { return }

            // Determine presenter VC
            let presentingVC: UIViewController? = {
                if let presenter = presenter {
                    return BluetoothManager.topMostViewController(from: presenter)
                }
                guard let scene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first(where: { $0.activationState == .foregroundActive }),
                      let window = scene.windows.first(where: { $0.isKeyWindow }),
                      let root = window.rootViewController else {
                    return nil
                }
                return BluetoothManager.topMostViewController(from: root)
            }()

            guard let vc = presentingVC else { return }

            // 동일 목적 Alert가 이미 떠 있는지 검사 (제목/메시지로 판별)
            if let existing = vc.presentedViewController as? UIAlertController,
               existing.title == "Bluetooth 꺼짐",
               existing.message == "1.접근권한설정을 확인하시고\n 2.설정 > Bluetooth > 켬 으로 블루투스를 켜주세요.\n" {
                return
            }

            // 여기까지 왔으면 실제로 Alert 표시
            let alert = UIAlertController(title: "Bluetooth 꺼짐",
                                          message: "1.접근권한설정을 확인하시고\n 2.설정 > Bluetooth > 켬 으로 블루투스를 켜주세요.\n",
                                          preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "취소", style: .cancel, handler: { _ in
                self.isShowingBluetoothOffAlert = false
                completion?(false)
            }))
            alert.addAction(UIAlertAction(title: "설정 열기", style: .default, handler: { [weak alert] _ in
                // 해제 플래그를 먼저 내리고, Alert를 닫은 뒤 설정으로 이동
                self.isShowingBluetoothOffAlert = false
                // 성공(true) 콜백 전달
                completion?(true)
                if let presenting = alert?.presentingViewController {
                    presenting.dismiss(animated: true) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                } else {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }))

            // 표시 직전에 플래그 ON
            self.isShowingBluetoothOffAlert = true

            vc.present(alert, animated: true, completion: nil)
        }
    }
//    // Convenience method for backward compatibility
//    public func presentBluetoothOffAlertIfNeeded() {
//        presentBluetoothOffAlertIfNeeded(from: nil)
//    }

    // Resolve top-most view controller from a given root
    private static func topMostViewController(from root: UIViewController?) -> UIViewController? {
        guard let root = root else { return nil }
        if let presented = root.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let nav = root as? UINavigationController {
            return topMostViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topMostViewController(from: tab.selectedViewController)
        }
        return root
    }
}

extension BluetoothManager: CBCentralManagerDelegate,CBPeripheralDelegate {
   
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onStateChange?(central.state)
        switch central.state {
        case .poweredOff:
            // Notify UI layer if it wants to handle UX itself
            onBluetoothPoweredOff?()
            // Show a friendly alert guiding user to Settings
//            presentBluetoothOffAlertIfNeeded()
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        // 중복 검사 (identifier로)
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
        onDiscover?(peripheral, RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ 연결 완료: \(peripheral.name ?? "알 수 없음")")
//        awaitingPairing = false   // Bonding 되지 않아도 연결되어 해제되는 문제 발생.
        
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil) // ✅ 서비스 검색 시작
        onConnect?(peripheral, nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ 연결 실패: \(peripheral.name ?? "알 수 없음") | \(String(describing: error))")
        onConnect?(peripheral, error)
        awaitingPairing = false
        // 🔥 페어링 삭제 감지
        if let err = error as? CBError, err.code == .peerRemovedPairingInformation {
            print("⚠️ 기기에서 페어링 정보 삭제됨 → 재연결 중단")
            onFailToConnect?(peripheral, error)
            return
        }

        
        // 기타 오류 → 재시도 가능
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.connect(peripheral)
        }
    }


    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 연결 해제")

        guard !awaitingPairing else { return }
        print("🔌 onDisconnect")
        onDisconnect?(peripheral, error)
    }

   
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ 서비스 검색 에러:", error)
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            print("⚠️ 서비스 없음 — 아마도 Passkey 미입력")
            return
        }
        
        for service in services {
            print("🔹 서비스 발견:", service.uuid)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("❌ Characteristic 검색 에러:", error)
            return
        }
        let targetWCharacteristicUUID = CBUUID(string: "ABF1")   // ABF1:W,ABF2:R
        let targetRCharacteristicUUID = CBUUID(string: "ABF2")   // ABF1:W,ABF2:R
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            guard !awaitingPairing else { return }
            print("🔸 characteristic 발견:", characteristic.uuid)
            // 쓰기용
            if characteristic.uuid == targetWCharacteristicUUID {
                self.writeCharacteristic = characteristic
                print("✅ writeCharacteristic 설정 완료: \(characteristic.uuid)")
            }
            
            // 읽기/Notify용
            if characteristic.uuid == targetRCharacteristicUUID {
                self.readCharacteristic = characteristic  // 따로 변수 만들어 저장
                print("✅ readCharacteristic 설정 완료: \(characteristic.uuid)")
                // Notify 구독 시작
                subscribeToCharacteristic(characteristic)
            }
        }
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                       didUpdateValueFor characteristic: CBCharacteristic,
                       error: Error?) {
        if let error = error as? CBATTError, error.code == .insufficientAuthentication {
            awaitingPairing = true
            print("🔑 페어링 필요")
        } else {
            awaitingPairing = false
            print("✅ 이미 bonded 또는 인증 불필요")
        }
        
        
        if let error = error {
            print("❌ 데이터 수신 실패:", error)
            return
        }
    
       guard let data = characteristic.value else { return }

       // 콜백 전달
       onReceiveData?(data)

       // 문자열로 변환
       if let str = String(data: data, encoding: .utf8) {
           print("📡 수신 데이터:", str)
       } else {
           print("📡 수신 데이터 (바이너리):", data)
       }
   }

   func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
       if let error = error {
           print("❌ 쓰기 실패:", error)
       } else {
           print("✅ 데이터 전송 성공: \(characteristic.uuid)")
       }
   }

}
