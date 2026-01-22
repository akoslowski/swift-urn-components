import struct Foundation.CharacterSet

/// Represents a uniform resource name (URN)
///
/// See https://datatracker.ietf.org/doc/html/rfc8141
public struct URNComponents: CustomStringConvertible {

    /// URN scheme
    public let scheme: Scheme

    /// namespace ndentifier (NID): The identifier associated with a URN namespace.
    public let nid: NID

    /// namespace specific string (NSS): The URN-namespace-specific part of a URN.
    public let nss: NSS

    /// This specification includes three optional components in the URN
    /// syntax.  They are known as r-component, q-component, and f-component.
    public let rqf: RQF?

    private static let separator: String = ":"

    public init(
        scheme: String = "urn",
        nid: String,
        nss: String,
        rqf: String? = nil
    ) throws {
        self.scheme = try .init(string: scheme)
        self.nid = try .init(string: nid)
        self.nss = try .init(string: nss)
        self.rqf = .init(string: rqf)
    }

    public init(string: String) throws {
        let separators = string.ranges(of: URNComponents.separator)
        guard
            let schemeSeparator = separators.first,
            let nidSeparator = separators.dropFirst().first
        else {
            throw ParsingError.insufficientNumberOfURNComponents
        }

        let _scheme = string[string.startIndex..<schemeSeparator.lowerBound]
        let _nid = string[schemeSeparator.upperBound..<nidSeparator.lowerBound]
        let _nssEndIndex = URNComponents.nssEndIndex(string: string)
        let _nss = string[nidSeparator.upperBound..<_nssEndIndex]
        let _rqf = string[_nssEndIndex..<string.endIndex]

        try self.init(
            scheme: .init(_scheme),
            nid: .init(_nid),
            nss: .init(_nss),
            rqf: .init(String(_rqf))
        )
    }

    public var description: String {
        "\(assignedName)\(rqf, default: "")"
    }

    /// The combination of the "urn:" scheme, the NID, and
    /// the namespace specific string (NSS).  An "assigned-name" is
    /// consequently a substring of a URN (as defined above) if that URN
    /// contains any additional components.
    public var assignedName: String {
        [scheme.rawValue, nid.rawValue, nss.rawValue].joined(separator: URNComponents.separator)
    }
}

extension URNComponents: Decodable {
    public init(from decoder: any Decoder) throws {
        try self.init(
            string:
                try decoder
                .singleValueContainer()
                .decode(String.self)
        )
    }
}

extension URNComponents: Equatable, Hashable {
    public static func == (lhs: URNComponents, rhs: URNComponents) -> Bool {
        lhs.assignedName == rhs.assignedName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(assignedName)
    }
}

extension URNComponents {
    public struct Scheme: ExpressibleByStringLiteral, Equatable {
        let rawValue: String

        public init(string: String) throws {
            guard string.caseInsensitiveCompare("urn") == .orderedSame else {
                throw URNComponents.ParsingError.unsupportedURNScheme
            }

            rawValue = string.lowercased()
        }

        public init(stringLiteral value: StringLiteralType) {
            do {
                try self.init(string: value)
            } catch {
                preconditionFailure("Scheme is invalid: \(error)")
            }
        }
    }

    public struct NID: ExpressibleByStringLiteral, Equatable {
        let rawValue: String

        public init(string: String) throws {
            if string.isEmpty {
                throw URNComponents.ParsingError.missingNamespaceIdentifier
            }

            if string.count < 2 {
                throw URNComponents.ParsingError.invalidNamespaceIdentifierMinimumLength
            }

            if string.count > 30 {
                throw URNComponents.ParsingError.invalidNamespaceIdentifierMaximumLength
            }

            guard string.rangeOfCharacter(from: .namespaceIdentifier.inverted) == nil else {
                throw URNComponents.ParsingError.invalidCharactersInNamespaceIdentifier
            }

            rawValue = string.lowercased()
        }

        public init(stringLiteral value: StringLiteralType) {
            do {
                try self.init(string: value)
            } catch {
                preconditionFailure("NID is invalid: \(error)")
            }
        }
    }

    public struct NSS: ExpressibleByStringLiteral, Equatable {
        let rawValue: String

        public init(string: String) throws {
            if string.isEmpty {
                throw URNComponents.ParsingError.missingNamespaceSpecificString
            }

            let result = string.uppercasedPercentEncodingTriplets()
            let isPercentEncoded = result.ranges.isEmpty == false

            let characterSet: CharacterSet = if isPercentEncoded {
                .percentEncodedNamespaceSpecificString
            } else {
                .namespaceSpecificString
            }
            guard string.rangeOfCharacter(from: characterSet.inverted) == nil else {
                throw URNComponents.ParsingError.invalidCharactersInNamespaceSpecificString
            }

            rawValue = result.value
        }

        public init(stringLiteral value: StringLiteralType) {
            do {
                try self.init(string: value)
            } catch {
                preconditionFailure("NSS is invalid: \(error)")
            }
        }

        /// Elements from the namespace specific string separated by ':'
        public var elements: [String] {
            rawValue.split(separator: URNComponents.separator).map(String.init)
        }
    }

    public struct ParameterItem: Equatable {
        let name: String
        let value: String
    }

    public struct RQF: Decodable, CustomStringConvertible {
        public let resolution: String?
        public let query: String?
        public let fragment: String?

        public init?(resolution: String?, query: String?, fragment: String?) {
            if resolution == nil, query == nil, fragment == nil {
                return nil
            }
            self.resolution = resolution
            self.query = query
            self.fragment = fragment
        }

        public init?(string: String?) {
            guard
                let string,
                let values = rqfValues(in: string)?.map({ (key: $0, value: String($1), keyRange: $2) })
            else {
                return nil
            }
            let resolution = values.first(where: { $0.key == .resolutionIndicator })
            let query = values.first(where: { $0.key == .queryIndicator })
            let fragment = values.first(where: { $0.key == .fragmentIndicator })

            self.init(
                resolution: resolution?.value,
                query: query?.value,
                fragment: fragment?.value
            )
        }

        var resolutionItems: [ParameterItem] {
            URNComponents.parameters(in: resolution ?? "").map(ParameterItem.init)
        }

        var queryItems: [ParameterItem] {
            URNComponents.parameters(in: query ?? "").map(ParameterItem.init)
        }

        public var description: String {
            [
                (String.resolutionIndicator, resolution),
                (.queryIndicator, query),
                (.fragmentIndicator, fragment),
            ]
            .filter { $1 != nil }
            .map { "\($0)\($1, default: "")" }
            .joined()
        }
    }
}

extension URNComponents {
    public enum ParsingError: Error {
        case insufficientNumberOfURNComponents
        case unsupportedURNScheme
        case missingNamespaceIdentifier
        case invalidCharactersInNamespaceIdentifier
        case invalidNamespaceIdentifierMinimumLength
        case invalidNamespaceIdentifierMaximumLength
        case invalidCharactersInNamespaceSpecificString
        case missingNamespaceSpecificString
    }
}

// MARK: -

extension CharacterSet {
    /// Characters for NamespaceIdentifier permitted by RFC 8141
    static var namespaceIdentifier: CharacterSet {
        .alphanumerics.union(["-"])
    }

    /// Allowed characters for NamespaceSpecificString before percent-encoding:
    /// - a pchar (as defined in the generic URI syntax in RFC 3986)
    /// - a forward slash (“/”) (explicitly permitted by RFC 8141).
    static var namespaceSpecificString: CharacterSet {
        .alphanumerics.union([
            "-", ".", "_", "~",
            "!", "$", "&", "'",
            "(", ")", "*", "+",
            ",", ";", "=", ":",
            "@", "/",
        ])
    }

    static var percentEncodedNamespaceSpecificString: CharacterSet {
        .namespaceSpecificString.union(["%"])
    }
}

extension String {
    /// Any percent-encoded characters in the NSS (that is, all character
    /// triplets that match the <pct-encoding> production found in
    /// Section 2.1 of the base URI specification [RFC3986]), by
    /// conversion to upper case for the digits A-F.
    ///
    /// See https://datatracker.ietf.org/doc/html/rfc8141#section-3.1
    /// - Returns: A tuple with a new instance of the current string with all triplets uppercased,
    /// and the ranges of the triplets.
    func uppercasedPercentEncodingTriplets() -> (value: String, ranges: [Range<String.Index>]) {
        var string = self
        let tripletRanges = ranges(of: /%[a-fA-F0-9]{2}/)
        for range in tripletRanges {
            string.replaceSubrange(range, with: self[range].uppercased())
        }
        return (string, tripletRanges)
    }
}

extension StringProtocol where Self == String {
    fileprivate static var resolutionIndicator: String { "?+" }
    fileprivate static var queryIndicator: String { "?=" }
    fileprivate static var fragmentIndicator: String { "#" }
}

extension Regex<AnyRegexOutput> {
    fileprivate static var resolutionIndicator: Self {
        .init(verbatim: .resolutionIndicator)
    }

    fileprivate static var queryIndicator: Self {
        .init(verbatim: .queryIndicator)
    }

    fileprivate static var fragmentIndicator: Self {
        .init(verbatim: .fragmentIndicator)
    }
}

extension URNComponents {
    static func rqfValues(in string: String) -> [(key: String, value: Substring, keyRange: Range<String.Index>)]? {
        let ranges = (
            string.range(of: .resolutionIndicator),
            string.range(of: .queryIndicator),
            string.range(of: .fragmentIndicator)
        )

        let tuples: [(String, Substring, Range<String.Index>)]? =
            switch ranges {
            case (let resolutionRange?, let queryRange?, let fragmentRange?):
                [
                    (.resolutionIndicator, string[resolutionRange.upperBound..<queryRange.lowerBound], resolutionRange),
                    (.queryIndicator, string[queryRange.upperBound..<fragmentRange.lowerBound], queryRange),
                    (.fragmentIndicator, string[fragmentRange.upperBound..<string.endIndex], fragmentRange),
                ]
            case (let resolutionRange?, let queryRange?, _):
                [
                    (.resolutionIndicator, string[resolutionRange.upperBound..<queryRange.lowerBound], resolutionRange),
                    (.queryIndicator, string[queryRange.upperBound..<string.endIndex], queryRange),
                ]
            case (let resolutionRange?, _, let fragmentRange?):
                [
                    (.resolutionIndicator, string[resolutionRange.upperBound..<fragmentRange.lowerBound], resolutionRange),
                    (.fragmentIndicator, string[fragmentRange.upperBound..<string.endIndex], fragmentRange),
                ]
            case (_, let queryRange?, let fragmentRange?):
                [
                    (.queryIndicator, string[queryRange.upperBound..<fragmentRange.lowerBound], queryRange),
                    (.fragmentIndicator, string[fragmentRange.upperBound..<string.endIndex], fragmentRange),
                ]
            case (let resolutionRange?, _, _):
                [
                    (.resolutionIndicator, string[resolutionRange.upperBound..<string.endIndex], resolutionRange)
                ]
            case (_, let queryRange?, _):
                [
                    (.queryIndicator, string[queryRange.upperBound..<string.endIndex], queryRange)
                ]
            case (_, _, let fragmentRange?):
                [
                    (.fragmentIndicator, string[fragmentRange.upperBound..<string.endIndex], fragmentRange)
                ]
            case (_, _, _):
                nil
            }

        return tuples
    }

    static func nssEndIndex(string: String) -> String.Index {
        rqfValues(in: string)?.first?.keyRange.lowerBound ?? string.endIndex
    }

    static func parameters(in string: String) -> [(name: String, value: String)] {
        string
            .split(separator: "&")
            .map {
                $0.split(separator: "=").map(String.init)
            }
            .compactMap { item -> (String, String)? in
                guard item.count == 2, let name = item.first, let value = item.last else {
                    return nil
                }
                return (name, value)
            }
    }
}
