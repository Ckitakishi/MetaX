# LoadableNib

`LoadableNib` helps you load views from xib file in a type-safe way. You'll be able to reuse UIView's subclass with simple code, no matter the class is the view's `Custom Class` or `File's Owner`. 

## Usage

Declare Your view to comform `Loadable` protocol:

If you use the class that named `SubclassName` as `File's Owner`:

```swift
instantiateFromNibOwner(SubclassName.self)
```

Or you just set the custom name for the view with `SubclassName`:

```swift
let instance:SubclassName = UIView().instantiateFromNib(SubclassName.self)
```

## Install

Supports from Swift 4. 

### CocoaPods

Add the following line to your `Podfile`:

```
pod 'LoadableNib', '~> 1.0'
```

Run `pod install`.

### Carthage

Add the following line to your `Cartfile`:

```ruby
github "Ckitakishi/LoadableNib" ~> 1.0
```

1. Run `carthage update`.
2. Find the `LoadableNib.framework` file at `/Carthage/Build/*/`, then add it to *Linked Frameworks and Libraries* in your project.

## License

MIT license.

