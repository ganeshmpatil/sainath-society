/**
 * Unified API resource clients for every soc_mitra_* module.
 * Each resource exports a tiny object with the HTTP verbs it supports so
 * pages can call e.g. `grievancesApi.list({ status: 'OPEN' })` without
 * having to know URL paths.
 */

import { apiClient } from './client'

// ---------- Shared types ----------
export interface ListResponse<T> {
  count: number
  [key: string]: T[] | number
}

const qs = (params?: Record<string, string | number | boolean | undefined>) => {
  if (!params) return ''
  const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== '')
  if (entries.length === 0) return ''
  return '?' + entries.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`).join('&')
}

// ---------- Residents ----------
export interface Resident {
  id: string
  name: string
  mobile: string
  flatId?: string
  role: 'MEMBER' | 'ADMIN'
  designation?: string
  isRegistered: boolean
  isActive: boolean
  flat?: { flatNumber: string; wing?: { name: string } }
}
export const residentsApi = {
  list: (params?: { role?: string; activeOnly?: boolean }) =>
    apiClient.get<{ residents: Resident[]; count: number }>(`/residents${qs(params)}`),
  get: (id: string) => apiClient.get<Resident>(`/residents/${id}`),
  create: (data: Partial<Resident>) => apiClient.post<Resident>('/residents', data),
  update: (id: string, data: Record<string, unknown>) => apiClient.put(`/residents/${id}`, data),
  deactivate: (id: string) => apiClient.delete(`/residents/${id}`),
}

// ---------- Flats ----------
export interface Flat {
  id: string
  flatNumber: string
  floor: number
  areaSqft: number
  ownerName: string
  wingId?: string
  wing?: { id: string; name: string }
}
export interface Wing { id: string; name: string }
export const flatsApi = {
  list: (params?: { wingId?: string }) =>
    apiClient.get<{ flats: Flat[]; count: number }>(`/flats${qs(params)}`),
  get: (id: string) => apiClient.get<Flat>(`/flats/${id}`),
  create: (data: Partial<Flat>) => apiClient.post<Flat>('/flats', data),
  update: (id: string, data: Record<string, unknown>) => apiClient.put(`/flats/${id}`, data),
  listWings: () => apiClient.get<{ wings: Wing[]; count: number }>(`/flats/wings`),
}

// ---------- Grievances ----------
export interface Grievance {
  id: string
  ticketNo: string
  title: string
  titleMr?: string
  description: string
  descriptionMr?: string
  category: string
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT'
  status: 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'REJECTED' | 'CLOSED'
  raisedByMemberId: string
  flatId?: string
  createdAt: string
  raisedBy?: Resident
  flat?: Flat
}
export const grievancesApi = {
  list: (params?: { status?: string }) =>
    apiClient.get<{ grievances: Grievance[]; count: number }>(`/grievances${qs(params)}`),
  get: (id: string) => apiClient.get<Grievance>(`/grievances/${id}`),
  create: (data: Partial<Grievance>) => apiClient.post<Grievance>('/grievances', data),
  updateStatus: (id: string, status: string, resolution?: string) =>
    apiClient.request(`/grievances/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status, resolution }),
    }),
  addComment: (id: string, comment: string, isInternal = false) =>
    apiClient.post(`/grievances/${id}/comments`, { comment, isInternal }),
}

// ---------- Notices ----------
export interface Notice {
  id: string
  title: string
  titleMr?: string
  body: string
  bodyMr?: string
  category: string
  isPinned: boolean
  isPublished: boolean
  createdAt: string
  createdBy?: Resident
}
export const noticesApi = {
  list: () => apiClient.get<{ notices: Notice[]; count: number }>('/notices'),
  get: (id: string) => apiClient.get<Notice>(`/notices/${id}`),
  create: (data: Partial<Notice>) => apiClient.post<Notice>('/notices', data),
  update: (id: string, data: Record<string, unknown>) =>
    apiClient.request(`/notices/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  delete: (id: string) => apiClient.delete(`/notices/${id}`),
}

// ---------- Vehicles ----------
export interface Vehicle {
  id: string
  registrationNo: string
  vehicleType: string
  make?: string
  model?: string
  color?: string
  parkingSlot?: string
  stickerNo?: string
  ownerMemberId: string
  flatId?: string
  owner?: Resident
  flat?: Flat
}
export const vehiclesApi = {
  list: () => apiClient.get<{ vehicles: Vehicle[]; count: number }>('/vehicles'),
  get: (id: string) => apiClient.get<Vehicle>(`/vehicles/${id}`),
  create: (data: Partial<Vehicle>) => apiClient.post<Vehicle>('/vehicles', data),
  update: (id: string, data: Record<string, unknown>) =>
    apiClient.request(`/vehicles/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  delete: (id: string) => apiClient.delete(`/vehicles/${id}`),
}

// ---------- Polls ----------
export interface PollOption { id: string; optionText: string; optionTextMr?: string; voteCount: number }
export interface Poll {
  id: string
  title: string
  titleMr?: string
  description?: string
  descriptionMr?: string
  status: 'DRAFT' | 'ACTIVE' | 'CLOSED' | 'CANCELLED'
  startsAt: string
  endsAt: string
  options: PollOption[]
}
export interface CreatePollPayload {
  title: string
  titleMr?: string
  description?: string
  descriptionMr?: string
  startsAt: string
  endsAt: string
  isAnonymous?: boolean
  options: { optionText: string; optionTextMr?: string }[]
}
export const pollsApi = {
  list: () => apiClient.get<{ polls: Poll[]; count: number }>('/polls'),
  get: (id: string) => apiClient.get<Poll>(`/polls/${id}`),
  create: (data: CreatePollPayload) => apiClient.post<Poll>('/polls', data),
  publish: (id: string) => apiClient.post(`/polls/${id}/publish`),
  close: (id: string) => apiClient.post(`/polls/${id}/close`),
  vote: (id: string, optionId: string) => apiClient.post(`/polls/${id}/vote`, { optionId }),
  results: (id: string) => apiClient.get<{ poll: Poll; totalVotes: number }>(`/polls/${id}/results`),
}

// ---------- Meetings ----------
export interface Meeting {
  id: string
  title: string
  titleMr?: string
  meetingType: string
  status: string
  scheduledAt: string
  location?: string
  agenda?: string
  agendaMr?: string
  minutesOfMeeting?: string
  minutesOfMeetingMr?: string
  attendees?: { memberId: string; status: string; member?: Resident }[]
  actionItems?: { id: string; title: string; ownerMemberId: string; dueDate?: string; status: string; owner?: Resident }[]
}
export const meetingsApi = {
  list: () => apiClient.get<{ meetings: Meeting[]; count: number }>('/meetings'),
  get: (id: string) => apiClient.get<Meeting>(`/meetings/${id}`),
  create: (data: Partial<Meeting>) => apiClient.post<Meeting>('/meetings', data),
  markAttendance: (id: string, memberId: string, status: string) =>
    apiClient.post(`/meetings/${id}/attendance`, { memberId, status }),
  saveMinutes: (id: string, minutes: string, minutesMr?: string, lock = false) =>
    apiClient.post(`/meetings/${id}/minutes`, { minutes, minutesMr, lock }),
  addActionItem: (id: string, data: { title: string; ownerMemberId: string; dueDate?: string }) =>
    apiClient.post(`/meetings/${id}/action-items`, data),
  myActionItems: () => apiClient.get<{ actionItems: Meeting['actionItems']; count: number }>(`/meetings/my-action-items`),
}

// ---------- Events ----------
export interface Event {
  id: string
  title: string
  titleMr?: string
  description?: string
  eventType: string
  status: string
  startTime: string
  endTime: string
  location?: string
  isRsvpRequired: boolean
  organizer?: Resident
}
export const eventsApi = {
  list: () => apiClient.get<{ events: Event[]; count: number }>('/events'),
  listUpcoming: () => apiClient.get<{ events: Event[]; count: number }>('/events/upcoming'),
  get: (id: string) => apiClient.get<Event>(`/events/${id}`),
  create: (data: Partial<Event>) => apiClient.post<Event>('/events', data),
  rsvp: (id: string, status: 'YES' | 'NO' | 'MAYBE', guestCount = 0) =>
    apiClient.post(`/events/${id}/rsvp`, { status, guestCount }),
}

// ---------- Hall bookings ----------
export interface HallBooking {
  id: string
  purpose: string
  purposeMr?: string
  eventType?: string
  expectedGuests?: number
  startTime: string
  endTime: string
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'CANCELLED' | 'COMPLETED'
  paymentStatus: string
  bookingCharge: number
  deposit: number
  bookedByMemberId: string
  bookedBy?: Resident
  flat?: Flat
}
export const hallBookingsApi = {
  list: () => apiClient.get<{ bookings: HallBooking[]; count: number }>('/hall-bookings'),
  get: (id: string) => apiClient.get<HallBooking>(`/hall-bookings/${id}`),
  create: (data: Partial<HallBooking>) => apiClient.post<HallBooking>('/hall-bookings', data),
  checkAvailability: (start: string, end: string) =>
    apiClient.get<{ available: boolean }>(`/hall-bookings/availability${qs({ start, end })}`),
  decide: (id: string, approve: boolean, reason?: string) =>
    apiClient.post(`/hall-bookings/${id}/decide`, { approve, reason }),
  cancel: (id: string) => apiClient.post(`/hall-bookings/${id}/cancel`),
}

// ---------- Tenants ----------
export interface Tenant {
  id: string
  name: string
  mobile: string
  email?: string
  status: string
  familyCount: number
  monthlyRent?: number
  agreementStart?: string
  agreementEnd?: string
  flat?: Flat
  owner?: Resident
}
export interface TenantMovement {
  id: string
  tenantId: string
  movementType: 'MOVE_IN' | 'MOVE_OUT'
  scheduledAt: string
  actualAt?: string
  vehicleDetails?: string
  notes?: string
}
export const tenantsApi = {
  list: () => apiClient.get<{ tenants: Tenant[]; count: number }>('/tenants'),
  get: (id: string) => apiClient.get<Tenant>(`/tenants/${id}`),
  create: (data: Partial<Tenant>) => apiClient.post<Tenant>('/tenants', data),
  approve: (id: string) => apiClient.post(`/tenants/${id}/approve`),
  recordMovement: (id: string, data: Partial<TenantMovement>) =>
    apiClient.post(`/tenants/${id}/movements`, data),
  listMovements: (id: string) =>
    apiClient.get<{ movements: TenantMovement[]; count: number }>(`/tenants/${id}/movements`),
}

// ---------- Finance: transactions & bills ----------
export interface FinancialTransaction {
  id: string
  receiptNo?: string
  txnType: string
  direction: 'CREDIT' | 'DEBIT'
  amount: number
  paymentStatus: string
  paymentMethod?: string
  description?: string
  createdAt: string
  memberId?: string
  member?: Resident
  flat?: Flat
}
export const transactionsApi = {
  list: (params?: { from?: string; to?: string }) =>
    apiClient.get<{ transactions: FinancialTransaction[]; count: number }>(`/transactions${qs(params)}`),
  get: (id: string) => apiClient.get<FinancialTransaction>(`/transactions/${id}`),
  create: (data: Partial<FinancialTransaction>) => apiClient.post<FinancialTransaction>('/transactions', data),
  summary: (params?: { from?: string; to?: string }) =>
    apiClient.get<{ credit: number; debit: number; net: number }>(`/transactions/summary${qs(params)}`),
  markPaid: (id: string, paymentMethod: string, transactionRef?: string) =>
    apiClient.post(`/transactions/${id}/mark-paid`, { paymentMethod, transactionRef }),
}

export interface MaintenanceBill {
  id: string
  billNo: string
  flatId: string
  memberId: string
  billingPeriod: string
  issueDate: string
  dueDate: string
  totalAmount: number
  amountPaid: number
  status: 'DRAFT' | 'ISSUED' | 'PAID' | 'OVERDUE' | 'WAIVED'
  flat?: Flat
  member?: Resident
}
export const billsApi = {
  list: (params?: { flatId?: string; period?: string }) =>
    apiClient.get<{ bills: MaintenanceBill[]; count: number }>(`/finance/bills${qs(params)}`),
  get: (id: string) => apiClient.get<MaintenanceBill>(`/finance/bills/${id}`),
  generate: (data: {
    billingPeriod: string
    dueDate: string
    maintenanceCharge: number
    sinkingFund?: number
    repairFund?: number
    waterCharge?: number
    otherCharges?: number
  }) => apiClient.post<{ created: number; skipped: number }>('/finance/bills/generate', data),
  pendingDues: () => apiClient.get<{ pendingAmount: number; unpaidCount: number }>('/finance/bills/pending-dues'),
  markPaid: (id: string, amount: number) =>
    apiClient.post(`/finance/bills/${id}/mark-paid`, { amount }),
}

// ---------- Bylaws ----------
export interface Bylaw {
  id: string
  section: string
  title: string
  titleMr?: string
  content: string
  contentMr?: string
  category?: string
  version: number
  isActive: boolean
}
export const bylawsApi = {
  list: () => apiClient.get<{ bylaws: Bylaw[]; count: number }>('/bylaws'),
  get: (id: string) => apiClient.get<Bylaw>(`/bylaws/${id}`),
  create: (data: Partial<Bylaw>) => apiClient.post<Bylaw>('/bylaws', data),
  amend: (id: string, newContent: string, reason?: string) =>
    apiClient.request(`/bylaws/${id}/amend`, {
      method: 'PATCH',
      body: JSON.stringify({ newContent, reason }),
    }),
}

// ---------- Inventory ----------
export interface InventoryItem {
  id: string
  name: string
  nameMr?: string
  category: string
  quantity: number
  unitPrice: number
  totalValue: number
  condition: string
  location?: string
  serialNo?: string
}
export const inventoryApi = {
  list: (params?: { category?: string }) =>
    apiClient.get<{ items: InventoryItem[]; count: number }>(`/inventory${qs(params)}`),
  get: (id: string) => apiClient.get<InventoryItem>(`/inventory/${id}`),
  create: (data: Partial<InventoryItem>) => apiClient.post<InventoryItem>('/inventory', data),
  update: (id: string, data: Record<string, unknown>) =>
    apiClient.request(`/inventory/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  delete: (id: string) => apiClient.delete(`/inventory/${id}`),
}

// ---------- Suggestions ----------
export interface Suggestion {
  id: string
  title: string
  titleMr?: string
  description: string
  descriptionMr?: string
  category?: string
  status: string
  upvoteCount: number
  adminResponse?: string
  createdAt: string
  raisedBy?: Resident
}
export const suggestionsApi = {
  list: (params?: { sortBy?: 'recent' | 'upvotes' }) =>
    apiClient.get<{ suggestions: Suggestion[]; count: number }>(`/suggestions${qs(params)}`),
  get: (id: string) => apiClient.get<Suggestion>(`/suggestions/${id}`),
  create: (data: Partial<Suggestion>) => apiClient.post<Suggestion>('/suggestions', data),
  upvote: (id: string) => apiClient.post(`/suggestions/${id}/upvote`),
  respond: (id: string, status: string, response?: string, responseMr?: string) =>
    apiClient.post(`/suggestions/${id}/respond`, { status, response, responseMr }),
}

// ---------- Parking ----------
export interface ParkingSlot {
  id: string
  slotNumber: string
  slotType: string
  location?: string
  allocatedToFlatId?: string
  allocatedToMemberId?: string
  allocatedAt?: string
  flat?: Flat
}
export const parkingApi = {
  list: () => apiClient.get<{ slots: ParkingSlot[]; count: number }>('/parking/slots'),
  get: (id: string) => apiClient.get<ParkingSlot>(`/parking/slots/${id}`),
  create: (data: Partial<ParkingSlot>) => apiClient.post<ParkingSlot>('/parking/slots', data),
  allocate: (id: string, flatId: string, memberId: string) =>
    apiClient.post(`/parking/slots/${id}/allocate`, { flatId, memberId }),
  release: (id: string) => apiClient.post(`/parking/slots/${id}/release`),
}

// ---------- Tasks ----------
export interface Task {
  id: string
  title: string
  titleMr?: string
  description?: string
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT'
  status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'OVERDUE' | 'CANCELLED'
  source: string
  dueDate?: string
  ownerMemberId: string
  owner?: Resident
  assignedBy?: Resident
}
export const tasksApi = {
  list: (params?: { ownerMemberId?: string }) =>
    apiClient.get<{ tasks: Task[]; count: number }>(`/tasks${qs(params)}`),
  get: (id: string) => apiClient.get<Task>(`/tasks/${id}`),
  create: (data: Partial<Task>) => apiClient.post<Task>('/tasks', data),
  updateStatus: (id: string, status: string) =>
    apiClient.request(`/tasks/${id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) }),
}
