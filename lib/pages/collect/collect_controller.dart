import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

part 'collect_controller.g.dart';

class CollectController = _CollectController with _$CollectController;

abstract class _CollectController with Store {
  Box setting = GStorage.setting;
  List<BangumiItem> get favorites => GStorage.favorites.values.toList();

  @observable
  ObservableList<CollectedBangumi> collectibles =
      ObservableList<CollectedBangumi>();

  void loadCollectibles() {
    collectibles.clear();
    collectibles.addAll(GStorage.collectibles.values.toList());
  }

  int getCollectType(int id) {
    CollectedBangumi? collectedBangumi = GStorage.collectibles.get(id);
    if (collectedBangumi == null) {
      return 0;
    } else {
      return collectedBangumi.type;
    }
  }

  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }
    CollectedBangumi collectedBangumi =
        CollectedBangumi(bangumiItem, DateTime.now(), type);
    await GStorage.collectibles.put(bangumiItem.id, collectedBangumi);
    await GStorage.collectibles.flush();
    loadCollectibles();
  }

  Future<void> deleteCollect(BangumiItem bangumiItem) async {
    await GStorage.collectibles.delete(bangumiItem.id);
    await GStorage.collectibles.flush();
    bool webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableCollect = await setting
        .get(SettingBoxKey.webDavEnableCollect, defaultValue: false);
    loadCollectibles();
    if (webDavEnable && webDavEnableCollect) {
      try {
        await updateCollect();
      } catch (e) {
        KazumiLogger().log(Level.error, '更新webDav追番记录失败 ${e.toString()}');
      }
    }
  }

  Future<void> updateCollect() async {
    KazumiLogger()
        .log(Level.debug, '提交到WebDav的追番列表长度 ${GStorage.collectibles.length}');
    await WebDav().updateCollectibles();
    loadCollectibles();
  }

  // migrate collect from old version (favorites)
  Future<void> migrateCollect() async {
    if (favorites.isNotEmpty) {
      for (BangumiItem bangumiItem in favorites) {
        await addCollect(bangumiItem, type: 1);
      }
      await GStorage.favorites.clear();
      await GStorage.favorites.flush();
      KazumiLogger().log(Level.debug, '检测到${favorites.length}条未分类追番记录, 已迁移');
    }
  }
}
