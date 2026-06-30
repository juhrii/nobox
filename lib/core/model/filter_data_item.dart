// =====================================================================
// FITUR: Base Model Data Filter
// FILE: lib/core/model/filter_data_item.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Class dasar untuk data yang akan ditampilkan di dalam dropdown/list filter (Id & Name)
// =====================================================================
class FilterDataItem {
  final String id;
  final String name;

  FilterDataItem({required this.id, required this.name});
}

// =====================================================================
// FITUR: Model Agen (Human Agent)
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Agen
// =====================================================================
class HumanAgentItem extends FilterDataItem {
  HumanAgentItem({required super.id, required super.name});
  
  factory HumanAgentItem.fromJson(Map<String, dynamic> json) {
    return HumanAgentItem(
      id: json['UserId']?.toString() ?? json['Id']?.toString() ?? '',
      name: json['DisplayName']?.toString() ?? json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

// =====================================================================
// FITUR: Model Deal (Transaksi)
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Deal
// =====================================================================
class DealItem extends FilterDataItem {
  DealItem({required super.id, required super.name});
  
  factory DealItem.fromJson(Map<String, dynamic> json) {
    return DealItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

// =====================================================================
// FITUR: Model Campaign (Kampanye)
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Campaign
// =====================================================================
class CampaignItem extends FilterDataItem {
  CampaignItem({required super.id, required super.name});
  
  factory CampaignItem.fromJson(Map<String, dynamic> json) {
    return CampaignItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
    );
  }
}

// =====================================================================
// FITUR: Model Link Item
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Tautan/Link
// =====================================================================
class LinkItem extends FilterDataItem {
  LinkItem({required super.id, required super.name});
  
  factory LinkItem.fromJson(Map<String, dynamic> json) {
    return LinkItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
    );
  }
}

// =====================================================================
// FITUR: Model Contact Item
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Kontak
// =====================================================================
class ContactItem extends FilterDataItem {
  ContactItem({required super.id, required super.name});
  
  factory ContactItem.fromJson(Map<String, dynamic> json) {
    return ContactItem(
      id: json['CtId']?.toString() ?? json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

// =====================================================================
// FITUR: Model Group Item
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Group
// =====================================================================
class GroupItem extends FilterDataItem {
  GroupItem({required super.id, required super.name});
  
  factory GroupItem.fromJson(Map<String, dynamic> json) {
    return GroupItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

// =====================================================================
// FITUR: Model Funnel Item
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Funnel
// =====================================================================
class FunnelItem extends FilterDataItem {
  FunnelItem({required super.id, required super.name});
  
  factory FunnelItem.fromJson(Map<String, dynamic> json) {
    return FunnelItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

// =====================================================================
// FITUR: Model Tag Item
// FUNGSI: Turunan dari FilterDataItem, menampung id & nama Tag
// =====================================================================
class TagItem extends FilterDataItem {
  TagItem({required super.id, required super.name});
  
  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}
