import Foundation
import Testing

@testable import URNComponents

@Suite("URN components parsing tests")
struct URNComponentsParsingTests {
    @Test func parseComponents() throws {
        let urn =
        "urn:"                                                    // schema
        + "example:"                                              // nid
        + "com.example.resources:image:0D7424B41077"              // nss
        + "?+resolution_key_1=resolution_value_1"                 // resolution
        + "?=query_key_1=query_value_1&query_key_2=query_value_2" // query
        + "#com.example"                                          // fragment

        let components = try URNComponents(string: urn)

        #expect(components.scheme == "urn")
        #expect(components.nid == "example")
        #expect(components.nss == "com.example.resources:image:0D7424B41077")
        #expect(components.nss.elements == ["com.example.resources", "image", "0D7424B41077"])
        #expect(components.assignedName == "urn:example:com.example.resources:image:0D7424B41077")
        #expect(components.description == urn)

        let rqf = try #require(components.rqf)

        #expect(rqf.resolution == "resolution_key_1=resolution_value_1")
        #expect(rqf.resolutionItems[0] == .init(name: "resolution_key_1", value: "resolution_value_1"))

        #expect(rqf.query == "query_key_1=query_value_1&query_key_2=query_value_2")
        #expect(rqf.queryItems[0] == .init(name: "query_key_1", value: "query_value_1"))
        #expect(rqf.queryItems[1] == .init(name: "query_key_2", value: "query_value_2"))

        #expect(rqf.fragment == "com.example")
    }

    @Test func createURNComponents() throws {
        let components = try URNComponents(
            scheme: "urn",
            nid: "example",
            nss: "com.example.resources:image:0D7424B41077",
            rqf: "?=key=value#root"
        )

        #expect(components.scheme == "urn")
        #expect(components.nid == "example")
        #expect(components.nss == "com.example.resources:image:0D7424B41077")
        #expect(components.description == "urn:example:com.example.resources:image:0D7424B41077?=key=value#root")
        #expect(components.rqf?.resolution == nil)
        #expect(components.rqf?.query == "key=value")
        #expect(components.rqf?.fragment == "root")
        #expect(components.rqf?.description == "?=key=value#root")
    }

    @Test func nonPercentEncodedTripletFails() throws {
        #expect(throws: URNComponents.ParsingError.self) {
            try URNComponents(string: "urn:example:100%ZZ")
        }
        #expect(throws: URNComponents.ParsingError.self) {
            try URNComponents(string: "urn:example:example%")
        }
    }

    @Test func exampleURNCreationDoesNotThrow() throws {
        _ = try URNComponents(string: "urn:example:weather?=op=map&lat=39.56&lon=-104.85&datetime=1969-07-21T02:56:15Z")
        _ = try URNComponents(string: "urn:example:1/406/47452/2")
        _ = try URNComponents(string: "urn:example:foo-bar-baz-qux?+CCResolve:cc=uk")
        _ = try URNComponents(string: "urn:example:foo-bar-baz-qux#somepart")
    }

    @Test func uppercasedTriplets() throws {
        #expect("Af %af ab %20".uppercasedPercentEncodingTriplets().value == "Af %AF ab %20")
        #expect("%0a%zz".uppercasedPercentEncodingTriplets().value == "%0A%zz")
    }

    @Test(arguments: [
        "URN:xn--:example",
        "urn:xn--:example",
        "urn:00:example",
    ]) func urnWithValidNamespaceIdentifer(_ urn: String) throws {
        _ = try URNComponents(string: urn)
    }

    @Test(arguments: [
        "urn:ab",
        "urn:a:example",
        "urn:???:example",
    ]) func urnWithInvalidNamespaceIdentifer(_ urn: String) throws {
        #expect(throws: URNComponents.ParsingError.self) {
            _ = try URNComponents(string: urn)
        }
    }

    @Test func createURNComponentsFromInvalidInput() throws {
        #expect(throws: URNComponents.ParsingError.missingNamespaceSpecificString) {
            _ = try URNComponents(string: "urn:ietf:")
        }
    }

    @Test func decodingComponentsFromJSON() throws {
        struct Example: Decodable {
            let urn: URNComponents
        }
        let data = Data(
        """
        { "urn": "urn:example:abc" }
        """.utf8
        )
        let decoded = try JSONDecoder().decode(Example.self, from: data)
        #expect(decoded.urn.assignedName == "urn:example:abc")
    }

    @Test func uuidURN() throws {
        let urn = "urn:uuid:D1BB9200-A3E6-4C73-B8FB-E8C0423CE99C"
        let components = try URNComponents(string: urn)
        #expect(components.nss == "D1BB9200-A3E6-4C73-B8FB-E8C0423CE99C")
    }
}

/// This section shows a variety of URNs (using the "example" NID defined
/// in [RFC6963]) that highlight the URN-equivalence rules.
///
/// See https://datatracker.ietf.org/doc/html/rfc8141#section-3.2
@Suite("URN equivalence tests")
struct URNComponentsEquivalenceTests {

    @Test func compareURNComponents() throws {
        let lhs = try URNComponents(
            scheme: "URN",
            nid: "EXAMPLE",
            nss: "com.example.resources:image:0D7424B41077",
            rqf: "?=key=value#root"
        )

        let rhs = try URNComponents(
            scheme: "urn",
            nid: "example",
            nss: "com.example.resources:image:0D7424B41077",
            rqf: "?=foo=bar"
        )

        #expect(lhs == rhs)
    }

    /// Scheme and NID are case insensitive
    ///
    /// First, because the scheme and NID are case insensitive, the following
    /// three URNs are URN-equivalent to each other:
    ///
    ///  - `urn:example:a123,z456`
    ///  - `URN:example:a123,z456`
    ///  - `urn:EXAMPLE:a123,z456`
    ///
    @Test func `Scheme and NID are case insensitive`() throws {
        let a = try URNComponents(string: "urn:example:a123,z456")
        let b = try URNComponents(string: "URN:example:a123,z456")
        let c = try URNComponents(string: "urn:EXAMPLE:a123,z456")

        #expect(a == b)
        #expect(a == c)
        #expect(b == a)
        #expect(b == c)
        #expect(c == a)
        #expect(c == b)
    }

    /// RQF components are not taken into account for URN-equivalence
    ///
    /// Second, because the r-component, q-component, and f-component are not
    /// taken into account for purposes of testing URN-equivalence, the
    /// following three URNs are URN-equivalent to the first three examples
    /// above:
    ///
    ///  - `urn:example:a123,z456?+abc`
    ///  - `urn:example:a123,z456?=xyz`
    ///  - `urn:example:a123,z456#789`
    ///
    @Test func `RQF components are not taken into account for URN-equivalence`() throws {
        let a = try URNComponents(string: "urn:example:a123,z456?+abc")
        let b = try URNComponents(string: "urn:example:a123,z456?=xyz")
        let c = try URNComponents(string: "urn:example:a123,z456#789")

        #expect(a == b)
        #expect(a == c)
        #expect(b == a)
        #expect(b == c)
        #expect(c == a)
        #expect(c == b)
    }

    /// The slash character and following characters are taken into account for URN-equivalence
    ///
    /// Third, because the "/" character (and anything that follows it) in
    /// the NSS is taken into account for purposes of URN-equivalence, the
    /// following URNs are not URN-equivalent to each other or to the six
    /// preceding URNs:
    ///
    /// - urn:example:a123,z456/foo
    /// - urn:example:a123,z456/bar
    /// - urn:example:a123,z456/baz
    ///
    @Test func `The slash character and following characters are taken into account for URN-equivalence`() throws {
        let a = try URNComponents(string: "urn:example:a123,z456/foo")
        let b = try URNComponents(string: "urn:example:a123,z456/bar")
        let c = try URNComponents(string: "urn:example:a123,z456/baz")

        #expect(a != b)
        #expect(a != c)
        #expect(b != a)
        #expect(b != c)
        #expect(c != a)
        #expect(c != b)
    }

    /// Percent-encoding is not decoded for URN-equivalence
    ///
    /// Fourth, because of percent-encoding, the following URNs are
    /// URN-equivalent only to each other and not to any of those above (note
    /// that, although %2C is the percent-encoded transformation of "," from
    /// the previous examples, such sequences are not decoded for purposes of
    /// testing URN-equivalence):
    ///
    /// - urn:example:a123%2Cz456
    /// - URN:EXAMPLE:a123%2cz456
    ///
    @Test func `Percent-encoding is not decoded, but normalized for URN-equivalence`() throws {
        let a = try URNComponents(string: "urn:example:a123,z456")
        let b = try URNComponents(string: "urn:example:a123%2Cz456")
        let c = try URNComponents(string: "URN:EXAMPLE:a123%2cz456")

        #expect(a != b)
        #expect(a != c)
        #expect(b == c)

        #expect(b.assignedName == c.assignedName)
    }

    /// Fifth, because characters in the NSS other than percent-encoded
    /// sequences are treated in a case-sensitive manner (unless otherwise
    /// specified for the URN namespace in question), the following URNs are
    /// not URN-equivalent to the first three URNs:
    ///
    ///  - urn:example:A123,z456
    ///  - urn:example:a123,Z456
    ///
    /// Sixth, on casual visual inspection of a URN presented in a human-
    /// oriented interface, the following URN might appear the same as the
    /// first three URNs (because U+0430 CYRILLIC SMALL LETTER A can be
    /// confused with U+0061 LATIN SMALL LETTER A), but it is not
    /// URN-equivalent to the first three URNs:
    ///
    ///  - urn:example:%D0%B0123,z456
    ///
    @Test func `NSS is treated in a case-sensitive manner`() throws {
        let a = try URNComponents(string: "urn:example:a123,z456")
        let b = try URNComponents(string: "URN:example:a123,z456")
        let c = try URNComponents(string: "urn:EXAMPLE:a123,z456")

        let d = try URNComponents(string: "urn:example:A123,z456")
        let e = try URNComponents(string: "urn:example:a123,Z456")
        let f = try URNComponents(string: "urn:example:%D0%B0123,z456")

        #expect(a != d)
        #expect(a != e)
        #expect(a != f)

        #expect(b != d)
        #expect(b != e)
        #expect(b != f)

        #expect(c != d)
        #expect(c != e)
        #expect(c != f)
    }
}

///
/// See https://datatracker.ietf.org/doc/html/rfc8141#section-2.3
@Suite("RQF component tests")
struct RQFComponentTests {
    /// The r-component is intended for passing parameters to URN resolution
    /// services and interpreted by those services.
    ///
    /// See https://datatracker.ietf.org/doc/html/rfc8141#section-2.3.1
    @Test func resolutionComponent() throws {
        let components = URNComponents.RQF(string: "?+param1=value1")

        #expect(components?.resolution == "param1=value1")
        #expect(components?.query == nil)
        #expect(components?.fragment == nil)
    }

    /// The q-component is intended for passing parameters to either the
    /// named resource or a system that can supply the requested service, for
    /// interpretation by that resource or system.
    ///
    /// See https://datatracker.ietf.org/doc/html/rfc8141#section-2.3.2
    @Test func queryComponent() throws {
        let components = URNComponents.RQF(string: "?=param1=value1&param2=value2")

        #expect(components?.resolution == nil)
        #expect(components?.query == "param1=value1&param2=value2")
        #expect(components?.fragment == nil)
    }

    /// The f-component is intended to be interpreted by the client as a
    /// specification for a location within, or region of, the named resource.
    ///
    /// See https://datatracker.ietf.org/doc/html/rfc8141#section-2.3.3
    @Test func fragmentComponent() throws {
        let components = URNComponents.RQF(string: "#example")

        #expect(components?.resolution == nil)
        #expect(components?.query == nil)
        #expect(components?.fragment == "example")
    }

    @Test func noRFQComponent() throws {
        #expect(URNComponents.RQF(string: "") == nil)
        #expect(URNComponents.RQF(string: "?") == nil)
        #expect(URNComponents.RQF(string: "some-value") == nil)
    }

    @Test func emptyRQFComponent() throws {
        let rqf = URNComponents.RQF(string: "?+?=#")
        #expect(rqf?.resolution == "")
        #expect(rqf?.query == "")
        #expect(rqf?.fragment == "")

        let r = URNComponents.RQF(string: "?+")
        #expect(r?.resolution == "")

        let q = URNComponents.RQF(string: "?=")
        #expect(q?.query == "")

        let f = URNComponents.RQF(string: "#")
        #expect(f?.fragment == "")
    }
}
