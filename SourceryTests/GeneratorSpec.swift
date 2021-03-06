import Quick
import Nimble
import Stencil
@testable import Sourcery

class GeneratorSpec: QuickSpec {
    override func spec() {

        describe("Generator") {

            let fooType = Type(name: "Foo", variables: [Variable(name: "intValue", typeName: "Int")], inheritedTypes: ["Decodable", "AlternativeProtocol"])
            let fooSubclassType = Type(name: "FooSubclass", inheritedTypes: ["Foo", "ProtocolBasedOnKnownProtocol"])
            let barType = Struct(name: "Bar", inheritedTypes: ["NSObject", "ProjectClass", "KnownProtocol", "Decodable"])

            let complexType = Struct(name: "Complex", accessLevel: .public, isExtension: false, variables: [])
            let fooVar = Variable(name: "foo", typeName: "Foo", accessLevel: (read: .public, write: .public), isComputed: false)
            fooVar.type = fooType
            let barVar = Variable(name: "bar", typeName: "Bar", accessLevel: (read: .public, write: .public), isComputed: false)
            barVar.type = barType

            complexType.variables = [
                fooVar,
                barVar,
                Variable(name: "fooBar", typeName: "Int", isComputed: true)
            ]

            let types = [
                    fooType,
                    fooSubclassType,
                    complexType,
                    barType,
                    Enum(name: "Options", accessLevel: .public, inheritedTypes: ["KnownProtocol"], cases: [Enum.Case(name: "optionA"), Enum.Case(name: "optionB")], containedTypes: [
                        Type(name: "InnerOptions", accessLevel: .public, variables: [
                            Variable(name: "foo", typeName: "Int", accessLevel: (read: .public, write: .public), isComputed: false)
                            ])
                        ]),
                    Enum(name: "FooOptions", accessLevel: .public, inheritedTypes: ["Foo", "KnownProtocol"], rawType: "Foo", cases: [Enum.Case(name: "fooA"), Enum.Case(name: "fooB")]),
                    Type(name: "NSObject", accessLevel: .none, isExtension: true, inheritedTypes: ["KnownProtocol"]),
                    Type(name: "ProjectClass", accessLevel: .none),
                    Type(name: "ProjectFooSubclass", inheritedTypes: ["FooSubclass"]),
                    Protocol(name: "KnownProtocol"),
                    Protocol(name: "AlternativeProtocol"),
                    Protocol(name: "ProtocolBasedOnKnownProtocol", inheritedTypes: ["KnownProtocol"])
            ]

            func generate(_ template: String) -> String {
                return (try? Generator.generate(types,
                        template: SourceryTemplate(templateString: template))) ?? ""
            }

            it("generates types.all by skipping protocols") {
                expect(generate("Found {{ types.all.count }} types")).to(equal("Found 9 types"))
            }

            it("generates types.protocols") {
                expect(generate("Found {{ types.protocols.count }} protocols")).to(equal("Found 3 protocols"))
            }

            it("generates types.classes") {
                expect(generate("Found {{ types.classes.count }} classes, first: {{ types.classes.first.name }}, second: {{ types.classes.last.name }}")).to(equal("Found 4 classes, first: Foo, second: ProjectFooSubclass"))
            }

            it("generates types.structs") {
                expect(generate("Found {{ types.structs.count }} structs, first: {{ types.structs.first.name }}")).to(equal("Found 2 structs, first: Complex"))
            }

            it("generates types.enums") {
                expect(generate("Found {{ types.enums.count }} enums, first: {{ types.enums.first.name }}")).to(equal("Found 2 enums, first: Options"))
            }

            it("feeds types.implementing specific protocol") {
                expect(generate("Found {{ types.implementing.KnownProtocol.count }} types")).to(equal("Found 6 types"))
                expect(generate("Found {{ types.implementing.Decodable.count|default:\"0\" }} types")).to(equal("Found 0 types"))
                expect(generate("Found {{ types.implementing.Foo.count|default:\"0\" }} types")).to(equal("Found 0 types"))
                expect(generate("Found {{ types.implementing.NSObject.count|default:\"0\" }} types")).to(equal("Found 0 types"))
                expect(generate("Found {{ types.implementing.Bar.count|default:\"0\" }} types")).to(equal("Found 0 types"))
            }

            it("feeds types.inheriting specific class") {
                expect(generate("Found {{ types.inheriting.KnownProtocol.count|default:\"0\" }} types")).to(equal("Found 0 types"))
                expect(generate("Found {{ types.inheriting.Decodable.count|default:\"0\" }} types")).to(equal("Found 0 types"))
                expect(generate("Found {{ types.inheriting.Foo.count }} types")).to(equal("Found 2 types"))
                expect(generate("Found {{ types.inheriting.NSObject.count|default:\"0\" }} types")).to(equal("Found 0 types"))
                expect(generate("Found {{ types.inheriting.Bar.count|default:\"0\" }} types")).to(equal("Found 0 types"))
            }

            it("feeds types.based specific type or protocol") {
                expect(generate("Found {{ types.based.KnownProtocol.count }} types")).to(equal("Found 6 types"))
                expect(generate("Found {{ types.based.Decodable.count }} types")).to(equal("Found 4 types"))
                expect(generate("Found {{ types.based.Foo.count }} types")).to(equal("Found 2 types"))
                expect(generate("Found {{ types.based.NSObject.count }} types")).to(equal("Found 1 types"))
                expect(generate("Found {{ types.based.Bar.count|default:\"0\" }} types")).to(equal("Found 0 types"))
            }

            describe("accessing specific type via type.Typename") {

                it("can render accessLevel") {
                   expect(generate("{{ type.Complex.accessLevel }}")).to(equal("public"))
                }

                it("generates type.TypeName") {
                    expect(generate("{{ type.Foo.name }} has {{ type.Foo.variables.first.name }} variable")).to(equal("Foo has intValue variable"))
                }

                it("generates contained types properly, type.ParentType.ContainedType properly") {
                    expect(generate("{{ type.Options.InnerOptions.variables.count }} variable")).to(equal("1 variable"))
                }

                it("generates enum properly") {
                    expect(generate("{% for case in type.Options.cases %} {{ case.name }} {% endfor %}")).to(equal(" optionA  optionB "))
                }

                it("classifies computed properties properly") {
                    expect(generate("{{ type.Complex.variables.count }}, {{ type.Complex.computedVariables.count }}, {{ type.Complex.storedVariables.count }}")).to(equal("3, 1, 2"))
                }

                it("can access variable type information") {
                    expect(generate("{% for variable in type.Complex.variables %}{{ variable.type.name }}{% endfor %}")).to(equal("FooBar"))
                }

                it("generates proper response for type.inherits") {
                    expect(generate("{% if type.Bar.inherits.ProjectClass %} TRUE {% endif %}")).to(equal(" TRUE "))
                    expect(generate("{% if type.Bar.inherits.Decodable %} TRUE {% endif %}")).toNot(equal(" TRUE "))
                    expect(generate("{% if type.Bar.inherits.KnownProtocol %} TRUE {% endif %}")).toNot(equal(" TRUE "))
                    expect(generate("{% if type.Bar.inherits.AlternativeProtocol %} TRUE {% endif %}")).toNot(equal(" TRUE "))

                    expect(generate("{% if type.ProjectFooSubclass.inherits.Foo %} TRUE {% endif %}")).to(equal(" TRUE "))
                }

                it("generates proper response for type.implements") {
                    expect(generate("{% if type.Bar.implements.ProjectClass %} TRUE {% endif %}")).toNot(equal(" TRUE "))
                    expect(generate("{% if type.Bar.implements.Decodable %} TRUE {% endif %}")).toNot(equal(" TRUE "))
                    expect(generate("{% if type.Bar.implements.KnownProtocol %} TRUE {% endif %}")).to(equal(" TRUE "))

                    expect(generate("{% if type.ProjectFooSubclass.implements.KnownProtocol %} TRUE {% endif %}")).to(equal(" TRUE "))
                    expect(generate("{% if type.ProjectFooSubclass.implements.AlternativeProtocol %} TRUE {% endif %}")).to(equal(" TRUE "))
                }

                it("generates proper response for type.based") {
                    expect(generate("{% if type.Bar.based.ProjectClass %} TRUE {% endif %}")).to(equal(" TRUE "))
                    expect(generate("{% if type.Bar.based.Decodable %} TRUE {% endif %}")).to(equal(" TRUE "))
                    expect(generate("{% if type.Bar.based.KnownProtocol %} TRUE {% endif %}")).to(equal(" TRUE "))

                    expect(generate("{% if type.ProjectFooSubclass.based.KnownProtocol %} TRUE {% endif %}")).to(equal(" TRUE "))
                    expect(generate("{% if type.ProjectFooSubclass.based.Foo %} TRUE {% endif %}")).to(equal(" TRUE "))
                    expect(generate("{% if type.ProjectFooSubclass.based.Decodable %} TRUE {% endif %}")).to(equal(" TRUE "))
                    expect(generate("{% if type.ProjectFooSubclass.based.AlternativeProtocol %} TRUE {% endif %}")).to(equal(" TRUE "))
                }
            }
        }
    }
}
