//
//  TunnelsController.swift
//  Runner
//
//  Created by Khánh Tô on 09/11/2023.
//

import Foundation
import WireGuardKit
import MobileCoreServices
import WireGuardKitGo
import WireGuardKitC
import wireguard_vpn

class TunnelsController
{
    var tunnelsManager: TunnelsManager?
    var onTunnelsManagerReady: ((TunnelsManager) -> Void)?
    
    func onInit() {
        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("error is2=",error)
            case .success(let tunnelsManager):
                self.setTunnelsManager(tunnelsManager: tunnelsManager)
                self.onTunnelsManagerReady?(tunnelsManager)
                self.onTunnelsManagerReady = nil
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotificationSetState(_:)),
                                               name: Notification.Name.notificationSetState, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotificationGetName(_:)),
                                               name: Notification.Name.notificationGetNames, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotificationGetStats(_:)), 
                                               name: Notification.Name.notificationGetStats, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotificationRemoveAllTunnels(_:)), 
                                               name: Notification.Name.notificationRemoveAllTunnels, object: nil)
    }
    
    @objc func handleNotificationSetState(_ notification: Notification) {
        print("Notification received! SetState")
        if let object = notification.object as? [String: Any] {
            if let tunnel: [String: Any] = object["tunnel"] as? [String: Any]{
                let state = (object["state"] as? Int) == 1
                if(state == false){
                    let tunnelName = tunnel["name"] as? String?
                    self.onDisconnecting(tunnelName: (tunnelName ?? "")!);
                    return;
                }
                if  let tunnelName = tunnel["name"] as? String,
                    let address = tunnel["address"] as? String,
                    let listenPort = tunnel["listenPort"] as? String,
                    let privateKey = tunnel["privateKey"] as? String,
                    let dnsServersString = tunnel["dnsServer"] as? String,
                    let peerPresharedKey = tunnel["peerPresharedKey"] as? String,
                    let peerPublicKey = tunnel["peerPublicKey"] as? String,
                    let peerAllowedIpString = tunnel["peerAllowedIp"] as? String,
                    let peerEndpoint = tunnel["peerEndpoint"] as? String {
                    
                    let dnsServers = dnsServersString.splitToArray(trimmingCharacters: .whitespacesAndNewlines)
                    let peerAllowedIps = peerAllowedIpString.splitToArray(trimmingCharacters: .whitespacesAndNewlines)
                    self.onConnecting(tunnelName: tunnelName, address: address, listenPort: listenPort, privateKey: privateKey, dnsServers: dnsServers, peerPresharedKey: peerPresharedKey, peerPublicKey: peerPublicKey, peerAllowedIps: peerAllowedIps, peerEndpoint: peerEndpoint);
                }
            }
        }
    }
    
    @objc func handleNotificationRemoveAllTunnels(_ notification: Notification) {
        print("Notification received! RemoveAllTunnels")
        tunnelsManager?.removeAllTunnels()
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelRemovedAll, object: [:])
    }
    
    @objc func handleNotificationGetName(_ notification: Notification) {
        print("Notification received! GetName")
        let containers = tunnelsManager?.mapTunnels(transform: { $0 })
        if let containers = containers{
            for container in containers{
                print(container.detail())
                if(container.status == .active){
                    WireguardVpnPlugin.sendEvent(message: EventNames.tunnelGetName, object: ["tunnelName": container.name])
                    return
                }
            }
        }
        // None of tunnel is running
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelGetName, object: [:])
    }
    
    @objc func handleNotificationGetStats(_ notification: Notification) {
        print("Notification received! GetStats")
        guard let tunnelName = notification.object as? String else{
            // Provide tunnel name to get statistics
            return
        }
        _ = tunnelsManager?.tunnel(named: tunnelName)
        // TODO: Implement get statistics for iOS
    }
    
    func setTunnelsManager(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        tunnelsManager.activationDelegate = self
        tunnelsManager.tunnelsListDelegate = self
    }
    
    func onDisconnecting(tunnelName: String){
        if let tunnel = self.tunnelsManager!.tunnel(named: tunnelName) {
            if  tunnel.status == .active {
                self.tunnelsManager!.startDeactivation(of: tunnel)
            }
        }
        self.disconnect(tunnelName: tunnelName)
    }
    
    func onConnecting(
        tunnelName: String,
        address: String,
        listenPort: String,
        privateKey: String,
        dnsServers: [String],
        peerPresharedKey: String,
        peerPublicKey: String,
        peerAllowedIps: [String],
        peerEndpoint: String) {
        if let tunnel = self.tunnelsManager!.tunnel(named: tunnelName) {
            if  tunnel.status == .active {
                self.tunnelsManager!.startDeactivation(of: tunnel)
            }
        }
       
        self.connecting(tunnelName: tunnelName)
    
        var interface = InterfaceConfiguration(privateKey: PrivateKey(base64Key: privateKey)!)
        interface.addresses = [IPAddressRange(from: String(format: address))!]
        interface.dns = dnsServers.map { DNSServer(from: $0)! }
        interface.listenPort = UInt16(listenPort)

        var peer = PeerConfiguration(publicKey: PublicKey(base64Key: peerPublicKey)!)
        peer.endpoint = Endpoint(from: peerEndpoint)
        peer.allowedIPs = peerAllowedIps.map {IPAddressRange(from: $0)!}
        peer.persistentKeepAlive = 25
        peer.preSharedKey = PreSharedKey(base64Key: peerPresharedKey)

        let tunnelConfiguration = TunnelConfiguration(name: tunnelName, interface: interface, peers: [peer])
        
        tunnelsManager?.add(tunnelConfiguration: tunnelConfiguration) { result in
            switch result {
            case .failure(let error):
                print("error is=",error)
                switch(error){
                case .tunnelAlreadyExistsWithThatName:
                    let tunnel = self.tunnelsManager!.tunnel(named: tunnelName)
                    self.tunnelsManager!.startActivation(of: tunnel!)
                    break;
                default:
                    // ErrorPresenter.showErrorAlert(error: error, from: qrScanViewController, onDismissal: completionHandler)
                    break;
                }
            case .success:
                print("added success")
                let tunnel = self.tunnelsManager!.tunnel(named: tunnelName)
                self.tunnelsManager!.startActivation(of: tunnel!)
               // completionHandler?()
                
            }
        }
    }
  
}
extension TunnelsController: TunnelsManagerActivationDelegate, TunnelsManagerListDelegate{
    // TunnelsManagerListDelegate
    func tunnelAdded(at index: Int, tunnel: TunnelContainer) {
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelAdded, object: ["tunnelName": tunnel.name])
    }
    
    func tunnelRemoved(at index: Int, tunnel: TunnelContainer) {
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelRemoved, object: ["tunnelName": tunnel.name])
    }
    
    // TunnelsManagerActivationDelegate
    func tunnelActivationAttemptFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationAttemptError) {
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelActivationAttemptFailed, object: ["tunnelName": tunnel.name])
        self.fail(tunnelName: tunnel.name)
    }
    
    func tunnelActivationAttemptSucceeded(tunnel: TunnelContainer) {
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelActivationAttemptSucceeded, object: ["tunnelName": tunnel.name])
        self.connected(tunnelName: tunnel.name)
    }
    
    func tunnelActivationFailed(tunnel: TunnelContainer) {
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelStatusFail, object: ["tunnelName": tunnel.name])
        self.fail(tunnelName: tunnel.name)
    }
    
    func tunnelActivationSucceeded(tunnel: TunnelContainer) {
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelActivationSucceeded, object: ["tunnelName": tunnel.name])
        self.connected(tunnelName: tunnel.name)
    }
    
    //
    func connected(tunnelName: String){
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelStatusConnected, object: ["tunnelName": tunnelName])
    }
    
    func connecting(tunnelName: String){
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelStatusConnecting, object: ["tunnelName": tunnelName])
    }
    
    func disconnect(tunnelName: String){
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelStatusDisconnect, object: ["tunnelName": tunnelName])
    }
    
    func fail(tunnelName: String){
        WireguardVpnPlugin.sendEvent(message: EventNames.tunnelStatusFail, object: ["tunnelName": tunnelName])
    }
    
}
