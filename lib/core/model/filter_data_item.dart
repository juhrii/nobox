class FilterDataItem {
  final String id;
  final String name;

  FilterDataItem({required this.id, required this.name});
}

class HumanAgentItem extends FilterDataItem {
  HumanAgentItem({required super.id, required super.name});
  
  factory HumanAgentItem.fromJson(Map<String, dynamic> json) {
    return HumanAgentItem(
      id: json['Id']?.toString() ?? json['UserId']?.toString() ?? '',
      name: json['DisplayName']?.toString() ?? json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

class DealItem extends FilterDataItem {
  DealItem({required super.id, required super.name});
  
  factory DealItem.fromJson(Map<String, dynamic> json) {
    return DealItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class CampaignItem extends FilterDataItem {
  CampaignItem({required super.id, required super.name});
  
  factory CampaignItem.fromJson(Map<String, dynamic> json) {
    return CampaignItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
    );
  }
}

class LinkItem extends FilterDataItem {
  LinkItem({required super.id, required super.name});
  
  factory LinkItem.fromJson(Map<String, dynamic> json) {
    return LinkItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
    );
  }
}

class ContactItem extends FilterDataItem {
  ContactItem({required super.id, required super.name});
  
  factory ContactItem.fromJson(Map<String, dynamic> json) {
    return ContactItem(
      id: json['CtId']?.toString() ?? json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

class GroupItem extends FilterDataItem {
  GroupItem({required super.id, required super.name});
  
  factory GroupItem.fromJson(Map<String, dynamic> json) {
    return GroupItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

class FunnelItem extends FilterDataItem {
  FunnelItem({required super.id, required super.name});
  
  factory FunnelItem.fromJson(Map<String, dynamic> json) {
    return FunnelItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}

class TagItem extends FilterDataItem {
  TagItem({required super.id, required super.name});
  
  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
    );
  }
}
