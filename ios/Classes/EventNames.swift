//
//  EventNames.swift
//  wireguard_vpn
//
//  Created by Khánh Tô on 11/11/2023.
//
public class EventNames{
    public static var methodGetTunnelNames = "getTunnelNames"
    public static var methodSetState = "setState"
    public static var methodGetStats = "getStats"
    public static var methodRemoveAllTunnels = "removeAllTunnels";
    
    
    public static var tunnelGetName = "tunnel_get_name"
    
    public static var tunnelAdded = "tunnel_added"
    public static var tunnelRemoved = "tunnel_removed"
    public static var tunnelRemovedAll = "tunnel_removed_all"
    public static var tunnelActivationAttemptFailed = "tunnel_activation_attempt_failed"
    public static var tunnelActivationAttemptSucceeded = "tunnel_activation_attempt_succeeded"
    public static var tunnelActivationFailed = "tunnel_activation_failed"
    public static var tunnelActivationSucceeded = "tunnel_activation_succeeded"
    public static var tunnelStatusConnected = "tunnel_status_connected"
    public static var tunnelStatusConnecting = "tunnel_status_connecting"
    public static var tunnelStatusDisconnect = "tunnel_status_disconnect"
    public static var tunnelStatusFail = "tunnel_status_fail"
    
}
extension Notification.Name {
    public static var notificationSetState = Notification.Name("wireguard_vpn_set_state")
    public static var notificationGetNames = Notification.Name("wireguard_vpn_get_names")
    public static var notificationGetStats = Notification.Name("wireguard_vpn_get_stats")
    public static var notificationRemoveAllTunnels = Notification.Name("wireguard_vpn_remove_all_tunnels")
}
