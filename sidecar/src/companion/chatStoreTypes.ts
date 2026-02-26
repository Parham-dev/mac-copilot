export type MessageRole = "user" | "assistant";

export type CompanionMessage = {
  id: string;
  role: MessageRole;
  text: string;
  createdAt: string;
};

export type CompanionChat = {
  id: string;
  projectId: string;
  title: string;
  lastUpdatedAt: string;
};

export type CompanionProject = {
  id: string;
  name: string;
  localPath: string;
  lastUpdatedAt: string;
};

export type PersistedChatState = {
  projects: CompanionProject[];
  chats: CompanionChat[];
  messagesByChat: Record<string, CompanionMessage[]>;
};

export type CompanionSnapshot = {
  projects?: CompanionProject[];
  chats?: CompanionChat[];
  messages?: Array<CompanionMessage & { chatId: string }>;
};

export const defaultPersistedChatState: PersistedChatState = {
  projects: [],
  chats: [],
  messagesByChat: {},
};
