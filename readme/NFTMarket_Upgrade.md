forge test --match-contract UpgradeableNFTMarketTest -vv 

MyERC721Upgradeable:     
1.基础NFT功能：铸造，转移，元数据存储
2.可升级性：使用UUPS代理，支持合约逻辑升级
3.访问控制：集成OwnableUpgradeable,只有合约所有者才能升级
4.id自增


NFTMarketV1:        
1.上架
2.购买
3.白名单
4.可升级

NFTMarketV2:           
1.继承V1所有的功能  
2.离线签名上架。listwithSignature   
3.增强授权检查。NFT的所有者必须调用setApprovalForAll来授权市场合约授权市场。
4.独立的签名管理。映射单独管理上架签名，避免与购买签名冲突。
5.为新的签名上架功能提供独立的重放攻击保护。

UpgradeableNFTMarketTest:   
### 测试覆盖功能：
- ✅ V1基础功能测试 ：验证基本的上架和购买功能
- ✅ 升级到V2测试 ：验证升级过程中状态保持不变
- ✅ V2签名上架功能 ：测试新增的离线签名上架功能
- ✅ 重放攻击保护 ：验证签名不能被重复使用
- ✅ 无效签名拒绝 ：确保错误签名被正确拒绝
- ✅ 授权检查 ：验证未授权操作被拒绝
- ✅ 完整升级工作流 ：端到端测试整个升级和功能验证流程