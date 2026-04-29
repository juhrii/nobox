class AppConfig {
  static const String appName = 'NoBox Chat';
  
  // Base URLs
  static const String baseUrl = 'https://id.nobox.ai/';
  static const String apiUrl = '${baseUrl}Services/';
  static const String authUrl = '${baseUrl}AccountAPI/';
  static const String inboxUrl = '${baseUrl}Inbox/';
  static const String signalRUrl = '${baseUrl}messagehub';
  static const String uploadUrl = '${baseUrl}upload/';

  // API Endpoints from Screenshot
  static const String generateTokenEndpoint = 'AccountAPI/GenerateToken';
  static const String contactListEndpoint = 'Services/Nobox/Contact/List';
  static const String channelListEndpoint = 'Services/Master/Channel/List';
  static const String accountListEndpoint = 'Services/Nobox/Account/List';
  static const String inboxSendEndpoint = 'Inbox/Send';
  static const String uploadBase64Endpoint = 'Inbox/UploadFile/ConvertBase64ToFile';

  // Application-specific mappings
  static const String sendMessageEndpoint = inboxSendEndpoint;
  static const String getConversationsEndpoint = contactListEndpoint;
  static const String getMessagesEndpoint = "Services/Chat/ChatMessages/List";

  // General Update Endpoints
  // NoBox uses a universal update endpoint for most properties (funnels, tags, campaigns, deals)
  static const String updateChatroomEndpoint = 'Services/Chat/Chatrooms/Update';
  static const String createChatnoteEndpoint = 'Services/Chat/Chatnotes/Create';
  static const String detailRoomEndpoint = 'Services/Chat/Chatrooms/DetailRoom';
  static const String detailArchivedEndpoint = 'Services/Chat/Chatrooms/DetailArchived';
  static const String chatroomsListEndpoint = 'Services/Chat/Chatrooms/List';
  static const String quickReplyTemplatesEndpoint = 'Services/Chat/Chattemplates/List';
  
  // Inbox Actions (MVC version as discovered by probe `Inbox/Assign?Id=x`)
  static const String assignInboxEndpoint = 'Inbox/Assign';
  static const String resolveInboxEndpoint = 'Inbox/Resolve';
  
  // Note: The toggle AI/NeedReply endpoints weren't in the cheat sheet, keeping standard generic for now.
  static const String toggleAiAgentEndpoint = 'Services/Nobox/Contact/ToggleAiAgent';
  static const String toggleNeedReplyEndpoint = 'Services/Nobox/Contact/ToggleNeedReply';

  // Agent Endpoints
  static const String getAgentsEndpoint = 'Services/Administration/User/ListAgent';
  static const String addAgentToConversationEndpoint = 'Services/Chat/Chatrooms/AddAgentToConversation';
  static const String resolveConversationEndpoint = 'Services/Chat/Chatrooms/MarkResolved';
  static const String moveArchiveEndpoint = 'Services/Chat/Chatrooms/MoveArchive';
  static const String restoreArchivedEndpoint = 'Services/Chat/Chatrooms/RestoreArchived';
  static const String assignContactEndpoint = 'Services/Chat/ContactReal/Assign';
  static const String saveContactEndpoint = 'Services/Chat/ContactReal/Assign';
  static const String listContactRealEndpoint = 'Services/Chat/ContactReal/List';
  static const String contactUpdateEndpoint = 'Services/Nobox/Contact/Update';

  // Funnel & Tags List Endpoints
  static const String funnelListEndpoint = 'Services/Chat/ChatFunnels/List';
  static const String tagsListEndpoint = 'Services/Chat/ChatTags/List';
  
  // Additional Filter Options
  static const String campaignsListEndpoint = 'Services/Master/Campaign/List';
  static const String dealsListEndpoint = 'Services/Master/Deal/List';
  static const String groupsListEndpoint = 'Services/Chat/Groups/List';
  static const String linksListEndpoint = 'Services/Chat/Links/List';

  // Form Template & Form Results Endpoints
  static const String formTemplateListEndpoint = 'Services/NoBoxCRM/Form/List';
  static const String formResultsListEndpoint = 'Services/NoBoxCRM/Formresults/List';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String settingsKey = 'app_settings';
  
  // App Constants
  static const int messagePageSize = 20;
}
