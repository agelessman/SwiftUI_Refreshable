// Authoer: The SwiftUI Lab
// Full article: https://swiftui-lab.com/scrollview-pull-to-refresh/
import SwiftUI

import SwiftUI

struct ContentView: View {
    @ObservedObject var model = MyModel()
    @State private var alternate: Bool = true

    var body: some View {
        
        return VStack(spacing: 0) {
            HeaderView(title: "SwiftUI下拉刷新")
               
            RefreshableScrollView(threshold: 70, refreshing: self.$model.loading) {
                
                DogView(cat: self.model.cat).padding(30).background(Color(UIColor.systemBackground))
                
            }.background(Color(UIColor.secondarySystemBackground))
        }
    }
    
    struct HeaderView: View {
        var title = ""
        
        var body: some View {
            VStack {
                Color(UIColor.systemBackground).frame(height: 30).overlay(Text(self.title))
                Color(white: 0.5).frame(height: 0.5)
            }
        }
    }
    
    struct DogView: View {
        let cat: Cat
        
        var body: some View {
            VStack {
                Image(cat.picture, defaultSystemImage: "questionmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 160)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .padding(2)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.1)))
                    .shadow(radius: 3)
                    .padding(4)
                
                Text(cat.name).font(.largeTitle).fontWeight(.bold)
                Text(cat.origin).font(.headline).foregroundColor(.blue)
                Text(cat.description)
                    .lineLimit(nil)
                    .frame(height: 1000, alignment: .top)
                    .padding(.top, 20)
            }
        }
    }
}

extension Image {
    init(_ name: String, defaultImage: String) {
        if let img = UIImage(named: name) {
            self.init(uiImage: img)
        } else {
            self.init(defaultImage)
        }
    }
    
    init(_ name: String, defaultSystemImage: String) {
        if let img = UIImage(named: name) {
            self.init(uiImage: img)
        } else {
            self.init(systemName: defaultSystemImage)
        }
    }
    
}

struct RefreshableScrollView<Content: View>: View {
    @State private var preOffset: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var frozen: Bool = false
    @State private var rotation: Angle = .degrees(0)
    
    var threshold: CGFloat = 80
    @Binding var refreshing: Bool
    let content: Content
    
    init(threshold: CGFloat = 80,
         refreshing: Binding<Bool>,
         @ViewBuilder content: () -> Content) {
        self.threshold = threshold
        self._refreshing = refreshing
        self.content = content()
    }
    
    var body: some View {
        VStack {
            ScrollView {
                ZStack(alignment: .top) {
                    MovingView()
                    
                    VStack {
                        self.content
                            .alignmentGuide(.top, computeValue: { d in
                                (self.refreshing && self.frozen) ? -self.threshold : 0
                            })
                    }
                    
                    SymbolView(height: self.threshold,
                               loading: self.refreshing,
                               frozen: self.frozen,
                               rotation: self.rotation)
                }
            }
            .background(FixedView())
            .onPreferenceChange(RefreshableTypes.PrefKey.self) { prefs in
                self.refreshLogic(values: prefs)
            }
        }
    }
    
    func refreshLogic(values: [RefreshableTypes.PrefData]) {
        DispatchQueue.main.async {
            let movingBounds = values.first(where: {$0.vType == .movingView})?.bounds ?? .zero
            let fixedBounds = values.first(where: {$0.vType == .fixedView})?.bounds ?? .zero
            
            self.offset = movingBounds.minY - fixedBounds.minY
            
            self.rotation = self.symbolRotation(self.offset)
            
            if !self.refreshing && (self.offset > self.threshold && self.preOffset <= self.threshold) {
                self.refreshing = true
            }
            
            if self.refreshing {
                if self.preOffset > self.threshold && self.offset <= self.threshold {
                    self.frozen = true
                }
            } else {
                self.frozen = false
            }
            
            self.preOffset = self.offset
        }
    }
    
    func symbolRotation(_ scrollOffset: CGFloat) -> Angle {
        if scrollOffset < self.threshold * 0.6 {
            return .degrees(0)
        } else {
            let h = Double(self.threshold)
            let d = Double(scrollOffset)
            let v = max(min(d - (h * 0.6), h * 0.4), 0)
            return .degrees(180 * v / (h * 0.4))
        }
    }
    
    struct MovingView: View {
        var body: some View {
            GeometryReader { geo in
                Color.clear.preference(key: RefreshableTypes.PrefKey.self, value: [RefreshableTypes.PrefData(vType: .movingView, bounds: geo.frame(in: .global))])
            }.frame(height: 0)
        }
    }
    
    struct FixedView: View {
        var body: some View {
            GeometryReader { geo in
                Color.clear.preference(key: RefreshableTypes.PrefKey.self, value: [RefreshableTypes.PrefData(vType: .fixedView, bounds: geo.frame(in: .global))])
            }
        }
    }
    
    struct SymbolView: View {
        var height: CGFloat
        var loading: Bool
        var frozen: Bool
        var rotation: Angle
        
        var body: some View {
            Group {
                if self.loading {
                    VStack {
                        Spacer()
                        ActivityRes()
                        Spacer()
                    }
                    .frame(height: height)
                    .fixedSize()
                    .offset(y: (self.loading && self.frozen) ? 0.0 : -height)
                } else {
                    Image(systemName: "arrow.down")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: height * 0.25, height: height * 0.25)
                        .fixedSize()
                        .padding(height * 0.375)
                        .rotationEffect(rotation)
                        .offset(y: (self.loading && self.frozen) ? 0.0 : -height)
                }
            }
        }
    }
}

struct ActivityRes: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        return UIActivityIndicatorView()
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.startAnimating()
    }
}

struct RefreshableTypes {
    enum ViewType: Int {
        case movingView
        case fixedView
    }
    
    struct PrefData: Equatable {
        let vType: ViewType
        let bounds: CGRect
    }
    
    struct PrefKey: PreferenceKey {
        typealias Value = [PrefData]
        
        static var defaultValue: [RefreshableTypes.PrefData] = []
        
        static func reduce(value: inout [RefreshableTypes.PrefData], nextValue: () -> [RefreshableTypes.PrefData]) {
            value.append(contentsOf: nextValue())
        }
    }
}
