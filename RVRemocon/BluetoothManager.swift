//
//  BluetoothManager.swift
//  RVRemocon
//
//  Created by 김선욱 on 10/2/25.
//


import Foundation
import CoreBluetooth

// 간단한 블루투스 매니저 싱글톤
final class BluetoothManager: NSObject {
    static let shared = BluetoothManager()

    private var central: CBCentralManager!
    
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    
    private(set) var discoveredPeripherals: [CBPeripheral] = []
    var onDiscover: ((_ peripheral: CBPeripheral, _ rssi: NSNumber) -> Void)?
    var onStateChange: ((_ state: CBManagerState) -> Void)?
    var onConnect: ((_ peripheral: CBPeripheral, _ error: Error?) -> Void)?
    var onDisconnect: ((_ peripheral: CBPeripheral, _ error: Error?) -> Void)?

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
        central.connect(peripheral, options: nil)
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
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic,
              peripheral.state == .connected else { return }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
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
        onConnect?(peripheral, nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onConnect?(peripheral, error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        onDisconnect?(peripheral, error)
    }
}
