//
//  QJConnectBluetoothViewController.m
//  AR-JNT
//
//  Created by willwei on 2017/5/26.
//  Copyright © 2017年 qj-vr. All rights reserved.
//

#import "QJConnectBluetoothViewController.h"
#import "QJConnectBluetoothView.h"

#import <CoreBluetooth/CoreBluetooth.h>

@interface QJConnectBluetoothViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) QJConnectBluetoothView *bluetoothView;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;

@end

@implementation QJConnectBluetoothViewController

- (void)dealloc {
    NSLog(@"dealloc: %@", self.class);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self startFlashSequenceAnimation];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Getter
- (QJConnectBluetoothView *)bluetoothView {
    if (!_bluetoothView) {
        _bluetoothView = [[QJConnectBluetoothView alloc] init];
        [self.view addSubview:_bluetoothView];
        [_bluetoothView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(UIEdgeInsetsZero);
        }];
    }
    return _bluetoothView;
}

#pragma mark - Flash Animation
- (void)startFlashSequenceAnimation {
    [self.bluetoothView qj_startFlashSequenceAnimation];
}

#pragma mark - HUD
- (void)showInfoWithStatus:(NSString *)status {
    [SVProgressHUD showImage:nil status:status];
    [SVProgressHUD dismissWithDelay:kProgressHUDShowDuration];
}

#pragma mark - CBCentralManagerDelegate
/**
 中心管理者初始化，触发此代理方法，判断手机蓝牙状态
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStateUnknown:
            NSLog(@"手机蓝牙状态 --->>> CBManagerStateUnknown");
            break;
        case CBManagerStateResetting:
            NSLog(@"手机蓝牙状态 --->>> CBManagerStateResetting");
            break;
        case CBManagerStateUnsupported:
            NSLog(@"手机蓝牙状态 --->>> CBManagerStateUnsupported");
            break;
        case CBManagerStateUnauthorized:
            NSLog(@"手机蓝牙状态 --->>> CBManagerStateUnauthorized");
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"手机蓝牙状态 --->>> CBManagerStatePoweredOff");
            [self showInfoWithStatus:@"蓝牙已关闭"];
            break;
        case CBCentralManagerStatePoweredOn:
            NSLog(@"手机蓝牙状态 --->>> CBCentralManagerStatePoweredOn");
            [self showInfoWithStatus:@"蓝牙已打开"];
            [self.centralManager scanForPeripheralsWithServices:nil options:nil]; // 搜索蓝牙设备
            break;
        default:
            break;
    }
}

/**
 发现外设
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([peripheral.name hasPrefix:@"ARGUN"]) {
        NSLog(@"已发现设备 --->>> peripheral: %@, RSSI: %@, advertisementData: %@", peripheral, RSSI, advertisementData);
        [self showInfoWithStatus:@"已发现设备"];
        self.peripheral = peripheral;
        [self.centralManager stopScan]; // 停止搜索
        [self.centralManager connectPeripheral:self.peripheral options:nil]; // 连接设备
    }
}

/**
 连接成功
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"连接成功 --->>> peripheral: %@", peripheral);
    [self showInfoWithStatus:@"连接成功"];
    peripheral.delegate = self; // 设置外设的代理
    [self.peripheral readRSSI];
    [self.peripheral discoverServices:nil]; // 开始外设服务,传nil代表不过滤
}

/**
 连接失败
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"连接失败 --->>> peripheral: %@", peripheral);
    [self showInfoWithStatus:@"连接失败"];
}

/**
 丢失连接
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"丢失连接 --->>> peripheral: %@", peripheral);
    [self showInfoWithStatus:@"丢失连接"];
}

#pragma mark - CBPeripheralDelegate
/**
 信号强度。调用readRSSI后触发
 */
- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error {
    int rssi = abs([RSSI intValue]);
    CGFloat ci = (rssi - 49) / (10 * 4.);
    NSLog(@"已读取信号强度值 --->>> %@, 距离: %.1fm", peripheral, pow(10, ci));
}

/**
 已发现服务后调用
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    CBService *interestingService;
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service --->>> %@", service);
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"FFF4"]]) {
            interestingService = service;
        }
    }
    [peripheral discoverCharacteristics:nil forService:interestingService];
}

/**
 已发现Characteristic后调用
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    NSLog(@"服务 --->>> service: %@", service);
    CBCharacteristic *interestingCharacteristic;
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Discovered characteristic --->>> %@", characteristic);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFF5"]]) {
            interestingCharacteristic = characteristic;
        }
    }
    if ((interestingCharacteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify) {
        [peripheral setNotifyValue:YES forCharacteristic:interestingCharacteristic];
    }
}

/**
 更新Characteristic的Value
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSLog(@"更新Characteristic的Value --->>> %@", characteristic);
}

/**
 更新Characteristic的NotificationState
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSLog(@"更新Characteristic的NotificationState --->>> %@", characteristic);
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    if (characteristic.isNotifying) {
        [peripheral readValueForCharacteristic:characteristic];
    } else {
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
}

@end
