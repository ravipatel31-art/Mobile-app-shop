import SwiftUI

/// Small colored icon chip used in cards and quick actions.
struct IconChip: View {
    let icon: String            // SF Symbol name
    var gradient: LinearGradient?
    var color: Color?
    var size: CGFloat = 44
    var iconSize: CGFloat = 22

    var body: some View {
        let fill: AnyShapeStyle =
            gradient.map { AnyShapeStyle($0) } ??
            AnyShapeStyle(color ?? CafePalette.latte)
        return RoundedRectangle(cornerRadius: size * 0.32)
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white)
            )
            .shadow(color: .black.opacity(gradient != nil ? 0.10 : 0),
                    radius: 10, y: 4)
    }
}

/// Section header with title, optional subtitle and trailing widget.
struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .heavy))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 4)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

/// KPI card with a colored accent — used on dashboards.
struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let gradient: LinearGradient
    var caption: String?

    var body: some View {
        HStack(spacing: 12) {
            IconChip(icon: icon, gradient: gradient, size: 42, iconSize: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(value).font(.system(size: 17, weight: .heavy))
                    .minimumScaleFactor(0.6).lineLimit(1)
                if let caption {
                    Text(caption).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.black.opacity(0.05)))
        )
    }
}

/// Tappable quick-action tile: gradient icon + label + optional badge.
struct QuickActionTile: View {
    let icon: String
    let label: String
    let gradient: LinearGradient
    var onTap: (() -> Void)?
    var badge: String?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 10) {
                IconChip(icon: icon, gradient: gradient, size: 40, iconSize: 19)
                Text(label).font(.system(size: 15, weight: .bold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(gradient.opacity(0.15)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.05)))
        )
    }
}

/// Friendly empty/error state with a cup glyph.
struct EmptyStateArt: View {
    let title: String
    var message: String?
    var action: AnyView?
    var icon: String = "cup.and.saucer"

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(CafePalette.coffee.opacity(0.55))
            Text(title).font(.system(size: 17, weight: .heavy))
                .multilineTextAlignment(.center)
            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let action { action }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
