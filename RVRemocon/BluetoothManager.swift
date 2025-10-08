//
//  BluetoothManager.swift
//  RVRemocon
//
//  Created by 김선욱 on 10/2/25.
//


import Foundation
import CoreBluetooth

// 간단한 블루투스 매니저 싱글톤
final class BluetoothManager: NSObject{
    static let shared = BluetoothManager()
    
    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?
    
    private(set) var discoveredPeripherals: [CBPeripheral] = []
    var onDiscover: ((_ peripheral: CBPeripheral, _ rssi: NSNumber) -> Void)?
    var onStateChange: ((_ state: CBManagerState) -> Void)?
    var onConnect: ((_ peripheral: CBPeripheral, _ error: Error?) -> Void)?
    var onDisconnect: ((_ peripheral: CBPeripheral, _ error: Error?) -> Void)?
    var onReceiveData: ((Data) -> Void)?
    // MARK: - 자동 재연결
    private var targetPeripheralIdentifier: UUID?
    
    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }
    
    // 외부에서 접근할 수 있는 읽기 전용 프로퍼티
    var state: CBManagerState {
        return central.state
    }

    // 스캔 시작
    func startScan() {
        guard central.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        // nil 서비스 -> 모든 광고 디바이스 스캔
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    // 스캔 중지
    func stopScan() {
        central.stopScan()
    }

    func connect(_ peripheral: CBPeripheral) {
        targetPeripheralIdentifier = peripheral.identifier
        
        // 이미 Bonded 되어 있는 장치 확인
//        let bonded = central.retrievePeripherals(withIdentifiers: [peripheral.identifier])
//        if let bondedPeripheral = bonded.first {
//            print("🔗 이미 Bonded 된 장치 발견 → 자동 연결")
//            self.connectedPeripheral = bondedPeripheral
//            bondedPeripheral.delegate = self
//            central.connect(bondedPeripheral, options: nil)
//        } else {
//            print("🔗 Bonded 안된 장치 →     유도")
            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            central.connect(peripheral, options: nil) // iOS가 자동으로 PASSKEY 요청
//        }
    }
    
    func disconnect(_ peripheral: CBPeripheral) {
        central.cancelPeripheralConnection(peripheral)
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


}

extension BluetoothManager: CBCentralManagerDelegate,CBPeripheralDelegate {
   
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onStateChange?(central.state)
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
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil) // ✅ 서비스 검색 시작
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onConnect?(peripheral, error)
        print("❌ 연결 실패: \(peripheral.name ?? "알 수 없음") | \(String(describing: error))")

        // 자동 재연결
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.connect(peripheral)
        }
    }


    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        onDisconnect?(peripheral, error)
    }
//}
//
//extension BluetoothManager: CBPeripheralDelegate {
   
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ 서비스 검색 에러:", error)
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            print("⚠️ 서비스 없음 — 아마도 Passkey 미입력")
            return
        }
        // 보호된 characteristic UUID만 접근
//        let protectedUUID = CBUUID(string: "ABF2")
//        var foundProtected = false
//
//        for service in services {
//            if let characteristics = service.characteristics {
//                for chr in characteristics {
//                    if chr.uuid == protectedUUID {
//                        foundProtected = true
//                        // Passkey 입력 유도
////                        peripheral.readValue(for: chr)
//                    }
//                }
//            }
//        }
//
//        if !foundProtected {
//            print("⚠️ 보호된 특성 없음 → Passkey 미입력 상태일 가능성")
//            return
//        }
//        
        
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
            print("🔸 characteristic 발견:", characteristic.uuid)
            // 쓰기용
            if characteristic.uuid == targetWCharacteristicUUID {
//            if characteristic.properties.contains(.write){
                self.writeCharacteristic = characteristic
                print("✅ writeCharacteristic 설정 완료: \(characteristic.uuid)")
            }
            
            // 읽기/Notify용
            if characteristic.uuid == targetRCharacteristicUUID {
//            if characteristic.properties.contains(.read) ||
//               characteristic.properties.contains(.notify) {
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
