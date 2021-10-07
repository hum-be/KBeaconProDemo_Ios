//
//  DeviceViewController.swift
//  KBeaconProDemo
//
//  Created by hogen on 2021/6/20.
//

import Foundation
import UIKit
import kbeaconlib2



class DeviceViewController :UIViewController, ConnStateDelegate, UITextFieldDelegate, NotifyDataDelegate
{
    static let ACTION_CONNECT = 0x0
    static let ACTION_DISCONNECT = 0x1
    static let TXT_DATA_MODIFIED = 0x1
    
    let GET_CFG_DURING_CONNECTING = true
    
    @IBOutlet weak var actionConnect: UIBarButtonItem!

    @IBOutlet weak var labelModel: UILabel!

    @IBOutlet weak var labelVersion: UILabel!

    @IBOutlet weak var txtName: UITextField!
    
    @IBOutlet weak var txtTxPower: UITextField!

    @IBOutlet weak var txtAdvPeriod: UITextField!

    @IBOutlet weak var txtBeaconUUID: UITextField!

    @IBOutlet weak var txtBeaconMajor: UITextField!

    @IBOutlet weak var txtBeaconMinor: UITextField!

    @IBOutlet weak var txtBeaconStatus: UITextView!

    @IBOutlet weak var labelBeaconType: UILabel!

    @IBOutlet weak var mLabelHardwareVersion: UILabel!
    
    var indicatorView:IndicatorViewController?

    weak var beacon: KBeacon?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard self.beacon != nil else{
            print("beacon is null")
            return
        }
                
        self.actionConnect.title = getString("BEACON_CONNECT")
        self.actionConnect.tag = DeviceViewController.ACTION_CONNECT
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap_ui(_:)))
        self.view.addGestureRecognizer(tap)
        self.txtName.delegate = self
        self.txtTxPower.delegate = self
        self.txtAdvPeriod.delegate = self
        self.txtBeaconUUID.delegate = self
        self.txtBeaconMajor.delegate = self
        self.txtBeaconMinor.delegate = self
    }
    
    @objc func tap_ui(_ tap:UITapGestureRecognizer)
    {
        UIApplication.shared.keyWindow?.endEditing(true)
    }
    
    @IBAction func onActionItemClick(_ sender: Any)
    {
        if (actionConnect.tag == DeviceViewController.ACTION_CONNECT)
        {
            let beaconPwd = KBPreferance.sharedPreferance.getBeaconPassword(beacon!.uuidString!)
            
            if (GET_CFG_DURING_CONNECTING)
            {
                //connect to device with default paramaters
                self.beacon!.connect(beaconPwd, timeout: 15.0, delegate: self)
            }
            else
            {
                //If the parameters are not read when connecting, the connection time will be less.
                let connPara = KBConnPara()
                connPara.syncUtcTime = true  //sync the phone's time to device
                connPara.readCommPara = true   //only read basic parameters (KBCfgCommon)
                connPara.readTriggerPara = false //not read trigger parameters
                connPara.readSlotPara = false    //not read advertisement parameters
                connPara.readSensorPara = false
                self.beacon!.connectEnhanced(beaconPwd, timeout: 15.0, connPara: connPara, delegate: self)
            }
            
            //show process dialog
            self.indicatorView = IndicatorViewController(title: getString("UPDATE_CONNECTING"), center: self.view.center)
            self.indicatorView?.startAnimating(self.view)
            
            actionConnect.title = getString("BEACON_DISCONNECT")
            actionConnect.tag = DeviceViewController.ACTION_DISCONNECT
        }
        else
        {
            self.beacon!.disconnect()
            actionConnect.title = getString("BEACON_CONNECT")
            actionConnect.tag = DeviceViewController.ACTION_CONNECT
        }
    }
    
    func onConnStateChange(_ beacon:KBeacon, state:KBConnState, evt:KBConnEvtReason)
    {
        if (state == KBConnState.Connecting)
        {
            self.txtBeaconStatus.text = "Connecting to device";
        }
        else if (state == KBConnState.Connected)
        {
            self.indicatorView?.stopAnimating()
            
            self.txtBeaconStatus.text = "Device connected";
            
            self.updateDeviceToView()
        }
        else if (state == KBConnState.Disconnected)
        {
            self.indicatorView?.stopAnimating()
            
            self.txtBeaconStatus.text = "Device disconnected";
            if (evt == KBConnEvtReason.ConnAuthFail)
            {
                NSLog("auth failed");
                self.showPasswordInputDlg(self.beacon!)
            }
        }
        
        self.updateActionButton()
    }
    
    //The device will read the device's configruation parameters while setup connection
    //so the app can get the common configruation after connection setup.
    func updateDeviceToView()
    {
        if let pCommonCfg = self.beacon!.getCommonCfg()
        {
            print("support max adv slot:\(pCommonCfg.getMaxSlot())")
            print("support max trigger:\(pCommonCfg.getMaxTrigger())")
            print("support iBeacon adv:\(pCommonCfg.isSupportIBeacon())")
            print("support eddy URL adv:\(pCommonCfg.isSupportEddyURL())")
            print("support eddy TLM adv:\(pCommonCfg.isSupportEddyTLM())")
            print("support eddy UID adv :\(pCommonCfg.isSupportEddyUID())")
            print("support KSensor adv:\(pCommonCfg.isSupportKBSensor())")
            print("support System adv:\(pCommonCfg.isSupportKBSystem())")
            print("support button:\(pCommonCfg.isSupportButton())")
            print("support beep:\(pCommonCfg.isSupportBeep())")
            print("support accleration:\(pCommonCfg.isSupportAccSensor())")
            print("support humidify:\(pCommonCfg.isSupportHumiditySensor())")
            print("support max Tx power:\(pCommonCfg.getMaxTxPower())")
            print("support min Tx power:\(pCommonCfg.getMinTxPower())")
            
            //adv type list
            if let advSlotList = self.beacon!.getSlotCfgList(){
                var advTypeDescs = ""
                for advSlot in advSlotList{
                    if (advSlot.getAdvType() != KBAdvType.AdvNull)
                    {
                        let advDesc = KBAdvType.getAdvTypeString(advSlot.getAdvType())
                        let slotIndex = advSlot.getSlotIndex()
                        advTypeDescs = "\(advTypeDescs)|slot:\(slotIndex):\(advDesc)"
                    }
                }
                self.labelBeaconType.text = advTypeDescs
            }
            
            self.txtName.text = pCommonCfg.getName()
            self.labelModel.text = pCommonCfg.getModel()
            self.labelVersion.text = pCommonCfg.getVersion()
            self.mLabelHardwareVersion.text = pCommonCfg.getHardwareVersion()
            
            //check if has iBeacon advertisement para
            if let iBeaconList = self.beacon!.getSlotCfgByAdvType(KBAdvType.IBeacon),
               let firstIBeaconAdv = iBeaconList[0] as? KBCfgAdvIBeacon
            {
                self.txtTxPower.text = "\(firstIBeaconAdv.getTxPower())"
                self.txtAdvPeriod.text = "\(firstIBeaconAdv.getAdvPeriod())"
                self.txtBeaconUUID.text = "\(firstIBeaconAdv.getUuid() ?? "")"
                self.txtBeaconMajor.text = "\(firstIBeaconAdv.getMajorID())"
                self.txtBeaconMinor.text = "\(firstIBeaconAdv.getMinorID())"
            }
            else
            {
                print("does not found iBeacon configruation in device")
            }
        }
        else
        {
            print("get common parameters failed, maybe the app does not requesting read common paramaters")
        }
    }
    
    //example1 : modify common parameters
    func updateCommPara()
    {
        let commCfg = KBCfgCommon()

        //check if parameters was changed
        if (txtName.tag == DeviceViewController.TXT_DATA_MODIFIED),
           let newName = txtName.text,
           newName.count > 0
        {
            commCfg.setName(newName)
        }
        else
        {
            print("no need configruation")
            return
        }
        
        //set device to always power on
        //the autoAdvAfterPowerOn is enable, the device will not allowed power off by long press button
        commCfg.setAlwaysPowerOn(true)
        
        self.beacon!.modifyConfig(obj: commCfg, callback: { (result, exception) in
            if (result)
            {
                print("config common para success")
            }
            else
            {
                print("config common para failed");
            }
        })
    }
    
    //example2 : modify iBeacon parameters
    func updateIBeaconPara()
    {
        if (self.beacon!.state != KBConnState.Connected)
        {
            print("beacon not connected")
            return;
        }
        
        
        let iBeaconCfg = KBCfgAdvIBeacon()
        iBeaconCfg.setSlotIndex(0)   //must be paramaters
        
        //tx power
        let commCfg = KBCfgCommon()
        if let strName = txtName.text
        {
            commCfg.setName(strName)
        }
            
        //tx power
        if let strTxPower = txtTxPower.text,
           let nTxPower = Int(strTxPower)
        {
            iBeaconCfg.setTxPower(nTxPower)
        }
        else
        {
            self.showDialogMsg("error", message:"tx power is invalid")
            return
        }
            
        //set adv period
        if let strAdvPeriod = txtAdvPeriod.text,
           let fAdvPeriod = Float(strAdvPeriod),
           (fAdvPeriod <= KBCfgAdvIBeacon.MAX_ADV_PERIOD && fAdvPeriod >= KBCfgAdvIBeacon.MIN_ADV_PERIOD )
        {
            iBeaconCfg.setAdvPeriod(fAdvPeriod)
        }
        else
        {
            self.showDialogMsg("error", message:"adv period is invalid")
            return
        }
        
        //modify ibeacon uuid
        if let uuid = txtBeaconUUID.text,
           uuid.isUUIDString()
        {
            iBeaconCfg.setUuid(uuid)
        }
        else
        {
            self.showDialogMsg("error", message:"uuid format is invalid")
            return
        }
        
        //modify ibeacon major id
        if let strMajorID = txtBeaconMajor.text,
           let nMajor = UInt(strMajorID)
        {
            iBeaconCfg.setMajorID(nMajor)
        }
        else
        {
            self.showDialogMsg("error", message:"major id format is invalid")
            return
        }
        
        //modify ibeacon major id
        if let strMinorID = txtBeaconMinor.text,
           let nMinor = UInt(strMinorID)
        {
            iBeaconCfg.setMinorID(nMinor)
        }
        else
        {
            self.showDialogMsg("error", message:"major id format is invalid")
            return
        }
        
        //set always advertisement (not trigger only)
        iBeaconCfg.setAdvTriggerOnly(false)
        iBeaconCfg.setAdvConnectable(true)         //allowed connectable
        
        let cfgArray = [commCfg, iBeaconCfg]
        
        self.beacon!.modifyConfig(array: cfgArray, callback: { (result, exception) in
            if (result)
            {
                self.showDialogMsg("success", message: "config success")
            }
            else if (exception != nil)
            {
                if (exception!.errorCode == KBErrorCode.CfgBusy)
                {
                    NSLog("Config busy, please make sure other configruation complete")
                }
                else if (exception!.errorCode == KBErrorCode.CfgTimeout)
                {
                    NSLog("Config timeout")
                }
                
                self.showDialogMsg("Failed", message:"config other error:\(exception!.errorCode)")
            }
        })
    }
    
    //example3: update KBeacon to hybid iBeacon/EddyTLM
    //the device broacasting iBeacon in Slot 0
    //and broadcasting TLM in Slot 1.
    func updateKBeaconToIBeaconTLM_unconnectable()
    {
        if (self.beacon!.state != KBConnState.Connected)
        {
            NSLog("beacon not connected")
            return
        }

        //iBeacon parameters
        let iBeaconAdv = KBCfgAdvIBeacon()
        iBeaconAdv.setSlotIndex(0)
        iBeaconAdv.setTxPower(KBAdvTxPower.RADIO_Neg12dBm)   //only used for nearby application
        iBeaconAdv.setAdvConnectable(false)    //not allowed connect
        iBeaconAdv.setAdvPeriod(1000.0)
        iBeaconAdv.setUuid("E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")
        iBeaconAdv.setMajorID(6454)
        iBeaconAdv.setMinorID(1458)
        
        //TLM parameters
        let eddyTLMAdv = KBCfgAdvEddyTLM()
        eddyTLMAdv.setSlotIndex(1)
        eddyTLMAdv.setTxPower(KBAdvTxPower.RADIO_0dBm)
        eddyTLMAdv.setAdvConnectable(false)
        eddyTLMAdv.setAdvPeriod(8000.0)

        //start configruation
        self.beacon!.modifyConfig(array:[iBeaconAdv, eddyTLMAdv], callback: { (result, exception) in
            if (result)
            {
                print("config iBeacon&TLM para success")
            }
            else
            {
                print("config iBeacon&TLM para failed");
            }
        })
    }
    
    //only update the modification para
    func updateModifyParaToDevice()
    {
        if (!self.beacon!.isConnected())
        {
            return
        }

        //First we get the current configuration of SLOT0, and then we only need to send the parameters that modified.
        if let oldIBeaconPara = self.beacon!.getSlotCfg(0) as? KBCfgAdvIBeacon
        {
            var bModification = false
            let iBeaconCfg = KBCfgAdvIBeacon();
            iBeaconCfg.setSlotIndex(0);  //must be parameters

            if (!oldIBeaconPara.isAdvConnectable()){
                iBeaconCfg.setAdvConnectable(true)
                bModification = true
            }

            if (oldIBeaconPara.isAdvTriggerOnly()){
                iBeaconCfg.setAdvTriggerOnly(false)
                bModification = true
            }

            if (oldIBeaconPara.getAdvPeriod() != 1280.0){
                iBeaconCfg.setAdvPeriod(1280.0)
                bModification = true
            }

            if (oldIBeaconPara.getTxPower() != KBAdvTxPower.RADIO_Neg4dBm){
                iBeaconCfg.setTxPower(KBAdvTxPower.RADIO_Neg4dBm)
                bModification = true
            }

            if (oldIBeaconPara.getUuid()!.compare("E2C56DB5-DFFB-48D2-B060-D0F5A71096E0") != .orderedSame){
                iBeaconCfg.setUuid("E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")
                bModification = true
            }

            if (oldIBeaconPara.getMajorID() != 645){
                iBeaconCfg.setMinorID(645)
                bModification = true
            }

            if (oldIBeaconPara.getMinorID() != 741){
                iBeaconCfg.setMinorID(741)
                bModification = true
            }

            //send parameters to device
            if (bModification)
            {
                self.beacon!.modifyConfig(obj:iBeaconCfg, callback: { (result, exception) in
                    if (result)
                    {
                        print("config iBeacon&TLM para success")
                    }
                    else
                    {
                        print("config iBeacon&TLM para failed");
                    }
                })
            }
            else
            {
                print("no need config")
            }
        }
        else
        {
            //...
        }
    }
    
    //example3: update device to broadcasting iBeacon adv
    func updateKBeaconToEddyURL()
    {
        if (self.beacon!.state != KBConnState.Connected)
        {
            NSLog("beacon not connected")
            return
        }

        //iBeacon parameters
        let eddyURLAdv = KBCfgAdvEddyURL()
        eddyURLAdv.setSlotIndex(0)
        eddyURLAdv.setAdvPeriod(1000.0)
        eddyURLAdv.setTxPower(KBAdvTxPower.RADIO_Neg20dBm)   //only for nearby (3~4 meters)
        eddyURLAdv.setAdvConnectable(true)
        eddyURLAdv.setUrl("https://www.google.com/")
        
        //turn off slot 1 advertisement
        let slot1NullAdv = KBCfgAdvNull()
        slot1NullAdv.setSlotIndex(1)
        
        //start configruation
        let configArray = [eddyURLAdv, slot1NullAdv]
        self.beacon!.modifyConfig(array:configArray, callback: { (result, exception) in
            if (result)
            {
                print("config iBeacon&TLM para success")
            }
            else
            {
                print("config iBeacon&TLM para failed");
            }
        })
    }
    
    func onNotifyDataReceived(_ beacon:KBeacon, evt:Int, data:Data)
    {
        NSLog("recieve event:\(evt), content:\(data.count)")
    }
    
    func updateActionButton()
    {
        if (beacon!.state == KBConnState.Connected)
        {
            actionConnect.title = getString("BEACON_DISCONNECT")
            actionConnect.tag = DeviceViewController.ACTION_DISCONNECT
        }
        else
        {
            actionConnect.title = getString("BEACON_CONNECT")
            actionConnect.tag = DeviceViewController.ACTION_CONNECT
        }
    }
    
    @IBAction func backToParentView(_ sender: Any)
    {
        self.navigationController?.popViewController(animated: true)
        self.beacon!.delegate = nil
        self.beacon!.disconnect()
    }
    
    

    @IBAction func onStartConfig(_ sender: Any)
    {
        if (self.beacon!.state != KBConnState.Connected){
            self.showDialogMsg(getString("ERR_TITLE"), message:getString("ERR_BEACON_NOT_CONNECTED"))
            return
        }
        
        self.updateIBeaconPara()
    }
    
    //enable button press trigger event to application
    func enableBtnTriggerEvtToApp()
    {
        //check if device can support button trigger capibility
        if let commCfg = self.beacon!.getCommonCfg(),
           !commCfg.isSupportTrigger(KBTriggerType.BtnSingleClick)
        {
            self.showDialogMsg("Fail", message: "device does not support button trigger")
            return
        }
                
        //trigger index is 0
        let btnTriggerPara = KBCfgTrigger(0, triggerType: KBTriggerType.BtnSingleClick)
        //set trigger action to app
        btnTriggerPara.setTriggerAction(KBTriggerAction.ReportToApp)
        
        self.beacon!.modifyConfig(obj: btnTriggerPara) { (result, exception) in
            if (result)
            {
                print("config trigger success")
            }
            else
            {
                print("config trigger failed");
            }
        }
    }
    
    //enable button press trigger event to slot1 advertisement
    func enableBtnTriggerEvtToSlot1Advertisement()
    {
        //check if device can support button trigger capibility
        if let commCfg = self.beacon!.getCommonCfg(),
           !(commCfg.isSupportTrigger(KBTriggerType.BtnSingleClick))
        {
            self.showDialogMsg("Fail", message: "device does not support button trigger")
            return
        }
                
        //trigger index is 0
        let btnTriggerPara = KBCfgTrigger(0, triggerType: KBTriggerType.BtnSingleClick)
        //set trigger action to app
        btnTriggerPara.setTriggerAction(KBTriggerAction.Advertisement)
        btnTriggerPara.setTriggerAdvSlot(1)
        btnTriggerPara.setTriggerAdvTime(10)   //advertisement 10 seconds
        btnTriggerPara.setTriggerAdvChangeMode(KBTriggerAdvChgMode.KBTriggerAdvChangeModeDisable)
        
        //slot 0 default advertisement (alive advertisement)
        let slot0DefaultAdv = KBCfgAdvIBeacon()
        slot0DefaultAdv.setSlotIndex(0)
        slot0DefaultAdv.setAdvPeriod(2000.0)
        slot0DefaultAdv.setTxPower(KBAdvTxPower.RADIO_0dBm)
        slot0DefaultAdv.setAdvConnectable(true)
        slot0DefaultAdv.setAdvTriggerOnly(false)   //always advertisement
        slot0DefaultAdv.setUuid("E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")
        slot0DefaultAdv.setMajorID(1)
        slot0DefaultAdv.setMinorID(4)
        
        //slot 1 trigger advertisement parameters
        let slot1TriggerAdv = KBCfgAdvIBeacon()
        slot1TriggerAdv.setSlotIndex(1)
        slot1TriggerAdv.setAdvPeriod(152.5)
        slot1TriggerAdv.setTxPower(KBAdvTxPower.RADIO_0dBm)
        slot1TriggerAdv.setAdvConnectable(false)
        slot1TriggerAdv.setAdvTriggerOnly(true)   //only advertisement when trigger happened
        slot1TriggerAdv.setUuid("E2C56DB5-DFFB-48D2-B060-D0F5A71096E2")
        slot1TriggerAdv.setMajorID(0)
        slot1TriggerAdv.setMinorID(2)
        
        let configArray = [btnTriggerPara, slot0DefaultAdv, slot1TriggerAdv]
        self.beacon!.modifyConfig(array:configArray) { (result, exception) in
            if (result)
            {
                self.showDialogMsg("success", message: "Config button trigger success")
            }
            else
            {
                self.showDialogMsg("Error", message: "Config button trigger failed")
            }
        }
    }

    @IBAction func onEnableButtonTrigger(_ sender: Any)
    {
        if (self.beacon!.state != KBConnState.Connected){
            self.showDialogMsg(getString("ERR_TITLE"), message: getString("ERR_BEACON_NOT_CONNECTED"))
            return;
        }
        
        //[self enableButtonTrigger];
        self.enableBtnTriggerEvtToSlot1Advertisement()
    }
    
    //disable trigger instance 0 (already config to button trigger)
    @IBAction func onDisableButtonTrigger(_ sender: Any)
    {
        if (self.beacon!.state != KBConnState.Connected){
            print("device does not connected")
            return
        }
        
        //turn off trigger instance 0
        let btnTriggerPara = KBCfgTrigger(0, triggerType: KBTriggerType.TriggerNull)
        btnTriggerPara.setTriggerAction(0)
        self.beacon!.modifyConfig(obj: btnTriggerPara) { (result, exception) in
            if (result)
            {
                print("Turn off btn trigger success")
            }
            else
            {
                print("Turn off btn trigger failed");
            }
        }
    }
    
    @IBAction func onEnableButtonTriggerEvent2App(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
            (commCfg.isSupportTrigger(KBTriggerType.BtnSingleClick)) else
        {
            print("not allowed to enable button trigger")
            return
        }

        //enable button trigger
        let btnTrigger = KBCfgTrigger(0, triggerType: KBTriggerType.BtnSingleClick)
        btnTrigger.setTriggerAction(KBTriggerAction.ReportToApp)
        self.beacon!.modifyConfig(obj: btnTrigger) { (result, exception) in
            if (result)
            {
                print("Enable button trigger to app")
                
                //subscribe button notification
                self.beacon!.subscribeSensorDataNotify(KBTriggerType.BtnSingleClick, notifyDelegate: self) { (result, exception) in
                    if (result){
                        print("subscribe button trigger notification success")
                    }else{
                        print("subscribe button trigger notification failed")
                    }
                }
            }
        }
    }
    
    @IBAction func onReadButtonTriggerPara(_ sender: Any)
    {
        if (self.beacon!.state != KBConnState.Connected){
            print("device does not connected")
            return
        }
        
        if self.beacon!.getTriggerCfg(KBTriggerType.BtnSingleClick) != nil
        {
            print("app already read button the parameters")
            return
        }
        
        //if the app does not read trigger parameters during connection, then the app can read the paramaters later
        self.beacon!.readTriggerConfig(KBTriggerType.BtnSingleClick) { (result, para, exception) in
            
            if (result),
               let btnTriggerPara = self.beacon!.getTriggerCfg(KBTriggerType.BtnSingleClick)
            {
                //print result
                print("trigger index:\(btnTriggerPara.getTriggerIndex())")
                print("trigger action:\(btnTriggerPara.getTriggerAction())")
                //...
            }
            
            /* parse the result by raw result
            if result,
               let triggerPara = para,
               let paraList = triggerPara[KBCfgTrigger.JSON_FIELD_TRIGGER_OBJ_LIST] as? [[String:Any]],
               paraList.count > 0
            {
                //parse the result from dictionary
                let cfgTrigger = KBCfgTrigger()
                cfgTrigger.updateConfig(paraList[0])
                
                //print result
                print("trigger index:\(cfgTrigger.getTriggerIndex() ?? -1)")
                print("trigger action:\(cfgTrigger.getTriggerAction() ?? -1)")
                //...
            }
            */
        }
    }
    
    @IBAction func onEnableMotionTrigger(_ sender: Any)
    {
        //check if device can support motion trigger capibility
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
            commCfg.isSupportTrigger(KBTriggerType.AccMotion) else
        {
            print("not allowed to modify motion parameters")
            return
        }
                
        //trigger index is 0
        let accTriggerPara = KBCfgTrigger(0, triggerType: KBTriggerType.AccMotion)
        //set trigger action to app
        accTriggerPara.setTriggerAction(KBTriggerAction.Advertisement)
        accTriggerPara.setTriggerAdvSlot(1)
        accTriggerPara.setTriggerAdvTime(5)   //advertisement 5 seconds
        accTriggerPara.setTriggerPara(3)    //motion sensitivity
        
        //we assumption the slot1 already config to iBeacon parameters
        //otherwise you need to config the slot1 parameters
        //please reference the enableBtnTriggerEvtToSlot1Advertisement for configruation slot1
        //...
        
        //enable motion trigger
        self.beacon!.modifyConfig(obj:accTriggerPara) { (result, exception) in
            if (result)
            {
                print("Enable motion trigger success")
            }
            else
            {
                print("Enable motion trigger failed");
            }
        }
    }
    
    //disable the trigger instance 0
    //Pre-condition: the trigger instance 0 was setting to motion trigger
    @IBAction func onDisableMotionTrigger(_ sender: Any)
    {
        //check if device can support motion trigger capibility
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
           commCfg.isSupportAccSensor() else
        {
            print("not allowed to modify motion parameters")
            return
        }
        
        //turn off trigger instance 0
        let accTriggerPara = KBCfgTrigger(0, triggerType: KBTriggerType.TriggerNull)
        accTriggerPara.setTriggerAction(0)
        self.beacon!.modifyConfig(obj: accTriggerPara) { (result, exception) in
            if (result)
            {
                print("Turn off motion trigger success")
            }
            else
            {
                print("Turn off motion trigger failed");
            }
        }
    }
    
    //update HT sensor parameters
    func setTHSensorMeasureParameters()
    {
        if (!self.beacon!.isConnected())
        {
            print("Device is not connected")
            return
        }

        //check device capability
        if let oldCommonCfg = self.beacon!.getCommonCfg(),
           oldCommonCfg.isSupportHumiditySensor()
        {
            print("Device does not supported ht sensor")
            return
        }

        //set trigger adv slot information
        let sensorHTPara = KBCfgSensorHT()
        //enable humidity sensor
        sensorHTPara.setLogEnable(true)

        //unit is second, set measure temperature and humidity interval
        sensorHTPara.setSensorHtMeasureInterval(2)

        //unit is 0.1%, if abs(current humidity - last saved humidity) > 3, then save new record
        sensorHTPara.setHumidityChangeThreshold(30)

        //unit is 0.1 Celsius, if abs(current temperature - last saved temperature) > 0.5, then save new record
        sensorHTPara.setTemperatureChangeThreshold(5)

        //enable sensor advertisement
        self.beacon!.modifyConfig(obj: sensorHTPara) { (result, exception) in
            if (result)
            {
                print("update ht parameters success")
            }
            else
            {
                print("update ht parameters failed")
            }
        }
    }
    
    @IBAction func onEnableAxisAdv(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
           (commCfg.isSupportAccSensor()) else
        {
            print("not allowed to modify motion parameters")
            return
        }

        //iBeacon parameters
        let sensorAdv = KBCfgAdvKSensor()
        sensorAdv.setSlotIndex(2)
        sensorAdv.setTxPower(KBAdvTxPower.RADIO_0dBm)
        sensorAdv.setAdvConnectable(false)    //not allowed connect
        sensorAdv.setAdvPeriod(3000.0)
        sensorAdv.setAxisSensorInclude(true)
        
        self.beacon!.modifyConfig(obj : sensorAdv) { (result, exception) in
            if (result)
            {
                print("Enable axis sensor adv success")
            }
            else
            {
                print("Enable axis sensor adv failed");
            }
        }

    }
    
    //enable device to include humidity and temp data in advertisement
    @IBAction func onTHLogData2Adv(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
           commCfg.isSupportHumiditySensor() else
        {
            print("not allowed to modify TH parameters")
            return
        }

        //sensor parameters
        let sensorAdv = KBCfgAdvKSensor()
        sensorAdv.setSlotIndex(2)
        sensorAdv.setTxPower(KBAdvTxPower.RADIO_0dBm)
        sensorAdv.setAdvConnectable(false)    //not allowed connect
        sensorAdv.setAdvPeriod(3000.0)
        sensorAdv.setHtSensorInclude(true)
        
        self.beacon!.modifyConfig(obj:sensorAdv) { (result, exception) in
            if (result)
            {
                print("Enable HT sensor adv success")
            }
            else
            {
                print("Enable HT sensor adv failed");
            }
        }
    }
    
    //enable device to send realtime measurement result to app
    @IBAction func onThLogData2App(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
           commCfg.isSupportHumiditySensor() else
        {
            print("not allowed to modify TH parameters")
            return
        }

        //iBeacon parameters
        let triggerAdv = KBCfgTrigger(0, triggerType: KBTriggerType.HTHumidityAbove)
        triggerAdv.setTriggerPara(0) //always true
        triggerAdv.setTriggerAction(KBTriggerAction.ReportToApp)
        self.beacon!.modifyConfig(obj: triggerAdv) { (result, exception) in
            if (result)
            {
                print("Enable report H&T data to app realtime")
                
                //subscribe HT notification
                self.beacon!.subscribeSensorDataNotify(KBTriggerType.HTHumidityAbove, notifyDelegate: self) { (result, exception) in
                    if (result){
                        print("enable report success")
                    }else{
                        print("enable report failed")
                    }
                }
            }
        }
    }
    
    @IBAction func onTHLogViewHistory(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
           commCfg.isSupportHumiditySensor() else
        {
            print("not allowed to modify TH parameters")
            return
        }
        
        self.performSegue(withIdentifier: "seqShowHistory", sender: self)
    }
    
    
    //enable temp above trigger
    //the device will start slot1 advertisement when temperature > 30 degree
    @IBAction func onTHTrigger2Adv(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
            commCfg.isSupportTrigger(KBTriggerType.HTTempAbove) else
        {
            print("device does not support temp above trigger")
            return
        }

        //trigger parameters
        let triggerAdv = KBCfgTrigger(0, triggerType: KBTriggerType.HTTempAbove)
        triggerAdv.setTriggerAction(KBTriggerAction.Advertisement)
        triggerAdv.setTriggerAdvSlot(1)  //please makesure the slot 1 was config
        triggerAdv.setTriggerAdvTime(10)
        triggerAdv.setTriggerAdvChangeMode(KBTriggerAdvChgMode.KBTriggerAdvChangeModeDisable)
        triggerAdv.setTriggerPara(30)    //trigger when temperature > 30 Celsius
        
        //config slot 1 parameters
        let slot1TriggerAdv = KBCfgAdvIBeacon()
        slot1TriggerAdv.setSlotIndex(1)
        slot1TriggerAdv.setAdvPeriod(152.5)
        slot1TriggerAdv.setTxPower(KBAdvTxPower.RADIO_0dBm)
        slot1TriggerAdv.setAdvConnectable(false)
        slot1TriggerAdv.setAdvTriggerOnly(true)   //only advertisement when trigger happened
        slot1TriggerAdv.setUuid("E2C56DB5-DFFB-48D2-B060-D0F5A71096E3")
        slot1TriggerAdv.setMajorID(0)
        slot1TriggerAdv.setMinorID(2)

        let configArray = [triggerAdv, slot1TriggerAdv]
        
        //set trigger
        self.beacon!.modifyConfig(array:configArray) { (result, exception) in
            if (result)
            {
                self.showDialogMsg("success", message: "Enable temp above trigger success")
            }
            else
            {
                self.showDialogMsg("error", message: "Enable temp above trigger failed")
            }
        }
    }
    
    @IBAction func onTHTriggerEvt2App(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
            commCfg.isSupportTrigger(KBTriggerType.HTTempAbove) else
        {
            print("not allowed to set trigger")
            return
        }

        let triggerApp = KBCfgTrigger(0, triggerType: KBTriggerType.HTTempAbove)
        triggerApp.setTriggerAction(KBTriggerAction.ReportToApp)
        triggerApp.setTriggerPara(50)  //trigger an event to app when temperature > 50 Celsius
        self.beacon!.modifyConfig(obj:triggerApp) { (result, exception) in
            if (result)
            {
                //subscribe HT notification
                self.beacon!.subscribeSensorDataNotify(KBTriggerType.HTTempAbove, notifyDelegate: self) { (result, exception) in
                    if (result){
                        print("subscribe trigger notification success")
                    }else{
                        print("subscribe trigger notification failed")
                    }
                }
            }
            else
            {
                print("enable trigger failed")
            }
        }
    }
    
    //After enable realtime data to app, then the device will periodically send the temperature and humidity data to app whether it was changed or not.
    func onTHMeasurementResult2AppRealtime(_ sender: Any)
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
            commCfg.isSupportTrigger(KBTriggerType.HTHumidityAbove) else
        {
            print("not allowed to set trigger")
            return
        }

        let triggerApp = KBCfgTrigger(0, triggerType: KBTriggerType.HTHumidityAbove)
        triggerApp.setTriggerAction(KBTriggerAction.ReportToApp)
        triggerApp.setTriggerPara(0)  //always True
        self.beacon!.modifyConfig(obj:triggerApp) { (result, exception) in
            if (result)
            {
                //subscribe HT notification
                self.beacon!.subscribeSensorDataNotify(KBTriggerType.HTHumidityAbove, notifyDelegate: self) { (result, exception) in
                    if (result){
                        print("subscribe trigger notification success")
                    }else{
                        print("subscribe trigger notification failed")
                    }
                }
            }
            else
            {
                print("enable trigger failed")
            }
        }
    }
    
    func onEnableCutoffTrigger()
    {
        guard self.beacon!.isConnected(),
            let commCfg = self.beacon!.getCommonCfg(),
            commCfg.isSupportTrigger(KBTriggerType.CutoffWatchband) else
        {
            print("device does not support cut off trigger")
            return
        }

        //enable cutoff trigger
        let cutoffTrigger = KBCfgTrigger(0, triggerType: KBTriggerType.CutoffWatchband)
        cutoffTrigger.setTriggerAction(KBTriggerAction.Advertisement)
        cutoffTrigger.setTriggerAdvSlot(0)  //please makesure the slot 0 was setting
        cutoffTrigger.setTriggerAdvTime(10)
        cutoffTrigger.setTriggerAdvChangeMode(KBTriggerAdvChgMode.KBTriggerAdvChangeModeUUID)
        
        self.beacon!.modifyConfig(obj: cutoffTrigger) { (result, exception) in
            if (result)
            {
                print("Enable cutoff trigger success")
            }
            else
            {
                print("Enable cutoff trigger failed")
            }
        }
    }
    
    
    @IBAction func onRingDevice(_ sender: Any)
    {
        guard self.beacon!.isConnected() else
        {
            print("devie not allowed beep")
            return
        }
        

        var paraDicts = [String:Any]()
        paraDicts["msg"] = "ring"
        
        //ring times, uint is ms
        paraDicts["ringTime"] = 10000
        
        //ring type 0x1: beep, 0x2: led flash
        paraDicts["ringType"] = 0x2
        
        //led flash on time. valid when ringType set to 0x0 or 0x2
        paraDicts["ledOn"] = 200

        //led flash off time. valid when ringType set to 0x0 or 0x2
        paraDicts["ledOff"] = 1800

        self.beacon?.sendCommand(paraDicts, callback: { (result, except) in
            if (result)
            {
                NSLog("send ring command to device success");
            }
            else
            {
                NSLog("send ring command to device failed");
            }
        })
    }
    
    
    @IBAction func onResetParametersToDefault(_ sender: Any)
    {
        guard self.beacon!.isConnected() else
        {
            print("devie not connected")
            return
        }
        

        var paraDicts = [String:Any]()
        paraDicts["msg"] = "admin"
        paraDicts["stype"] = "reset"
        self.beacon!.sendCommand(paraDicts, callback: { (result, except) in
            if (result)
            {
                NSLog("send reset command to device success");
            }
            else
            {
                NSLog("send reset command to device failed");
            }
        })
    }
    
    @IBAction func onDFUClick(_ sender: Any)
    {
        
        if self.beacon!.isConnected(),
            let commCfg = self.beacon?.getCommonCfg(),
            commCfg.isSupportSecurityDFU()
        {
            self.performSegue(withIdentifier: "seqCfgDFU", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let dfuCtrl = segue.destination as? KBDFUViewController
        {
            dfuCtrl.beacon = self.beacon
        }
        else if let viewHTLog = segue.destination as? CfgSensorDataHistoryController
        {
            viewHTLog.beacon = self.beacon
        }
    }
    
    func showPasswordInputDlg(_ beacon:KBeacon)
    {
        let passwordInputDlg = UIAlertController(title: getString("AUTH_FAIL"),
            message: getString("PWD_INPUT"),
            preferredStyle: .alert)
        passwordInputDlg.addTextField { (txtField) in
            txtField.placeholder = getString("PWD_HINT")
        }
        passwordInputDlg.addAction(UIAlertAction(title: getString("DLG_CANCEL"),
                                                 style: UIAlertAction.Style.cancel,
                                                 handler: nil))
        
        passwordInputDlg.addAction(UIAlertAction(title: getString("DLG_OK"),
                                                 style: UIAlertAction.Style.default,
                                                 handler: { (action) in
                                                    if let password = passwordInputDlg.textFields?[0].text
                                                    {
                                                        let pref = KBPreferance.sharedPreferance
                                                        pref.saveBeaconPassword(beacon.uuidString!, password: password)
                                                        
                                                        beacon.connect(password,
                                                                              timeout: 15.0,
                                                                              delegate: self)
                                                        
                                                        let connText = getString("BEACON_CONNECT")
                                                        self.indicatorView = IndicatorViewController(title: connText, center: self.view.center)
                                                        self.indicatorView?.startAnimating(self.view)
                                                    }
                                                 }))
        self.present(passwordInputDlg, animated: true, completion: nil)
    }
    
    func showDialogMsg(_ title:String, message:String)
    {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        
        let OKTitle = NSLocalizedString("DLG_OK", comment:"");
        let OkAction = UIAlertAction(title: OKTitle, style: UIAlertAction.Style.destructive, handler: nil)
        alertController.addAction(OkAction)
        self.navigationController!.present(alertController, animated: true, completion: nil)
    }
}
