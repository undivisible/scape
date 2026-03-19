import SwiftUI
import MirageKit

struct HostDashboardView: View {
    @ObservedObject var controller: HostController

    var body: some View {
        VStack(spacing: 16) {
            header

            Divider()
                .background(.secondary.opacity(0.3))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !controller.pendingConnectionApprovals.isEmpty {
                        approvalsSection
                    }

                    trustedDevicesSection

                    clientsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            footer
        }
        .frame(width: 380, height: 600)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "visionpro")
                .font(.system(size: 44))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolEffect(.bounce, value: controller.connectedClients.count)

            Text("Scape Host")
                .font(.title2.weight(.bold))

            Text(controller.status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var approvalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Approvals")
                .font(.headline)

            if !controller.pendingConnectionApprovals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connections")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(controller.pendingConnectionApprovals) { request in
                        approvalCard(
                            title: request.deviceInfo.name,
                            subtitle: "\(request.deviceInfo.deviceType.displayName) • \(request.deviceInfo.endpoint)",
                            detail: "Connection request",
                            requestedAt: request.requestedAt
                        ) {
                            approvalActions(
                                onReject: { controller.rejectConnection(request) },
                                onApprove: { controller.approveConnection(request) }
                            )
                        }
                    }
                }
            }

        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var trustedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trusted Devices")
                .font(.headline)

            if controller.trustedDeviceIDs.isEmpty {
                ContentUnavailableView {
                    Label("No Trusted Devices", systemImage: "checkmark.shield")
                } description: {
                    Text("Approved devices will appear here.")
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(controller.trustedDeviceIDs, id: \.self) { deviceID in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(deviceID.uuidString)
                                    .font(.caption)
                                    .monospaced()
                                    .textSelection(.enabled)
                                Text("Trusted device")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Revoke") {
                                controller.revokeTrustedDevice(deviceID)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var clientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Clients")
                .font(.headline)

            if controller.connectedClients.isEmpty {
                ContentUnavailableView {
                    Label("No Clients Connected", systemImage: "network.slash")
                } description: {
                    Text("Open Scape on your Vision Pro to connect.")
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(controller.connectedClients, id: \.id) { client in
                        HStack(spacing: 12) {
                            Image(systemName: client.deviceType.systemImage)
                                .foregroundStyle(.blue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.headline)
                                Text(client.deviceType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                exit(0)
            } label: {
                Label("Quit Scape", systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(.regularMaterial)
            .clipShape(Capsule())

            Spacer()

            Button {
                Task { try? await controller.start() }
            } label: {
                Label("Restart Service", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(.regularMaterial)
            .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    private func approvalCard<Actions: View>(
        title: String,
        subtitle: String,
        detail: String,
        requestedAt: Date,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(requestedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            actions()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func approvalActions(
        onReject: @escaping () -> Void,
        onApprove: @escaping () -> Void
    ) -> some View {
        HStack {
            Button("Reject", role: .destructive, action: onReject)
                .buttonStyle(.bordered)

            Spacer()

            Button("Approve", action: onApprove)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    HostDashboardView(controller: HostController())
}
