defineClass('ViewController', {
  handleBtn: function(sender) {
    var testOne = TestOneViewController.alloc().init()
    self.navigationController().pushViewController_animated(testOne, YES)
  }
});

defineClass('TestOneViewController');

