
var global = this;



;(function() {
  /*
      _ocCls[className] = {
        instanceMethods: {},
        classMethods: {}
      };
   */
  var _ocCls = {};

  // _JS_OC(1, 2,3);

  
  // _OC_defineClass(1, 2, 3);
  // return;


  function OCClass(instanceMethods, classMethods){
    this.instanceMethods = instanceMethods;
    this.classMethods = classMethods;
  }

  var _customMethods = {
      __c: function(methodName) {
          var slf = this;

          if (slf[methodName]) {
            slf[methodName].bind(slf);
          }

          var clsName = self.__clsName;
          if (clsName && _ocCls[clsName])
          {
              var methodType = slf.__obj ? 'instanceMethods': 'classMethods';
            if (_ocCls[clsName][methodType][methodName])
              {
                return _ocCls[clsName][methodType][methodName].bind(slf);
              }  
          }

          return function() {
            var args = Array.prototype.slice.call(arguments);
            return _methodFunc(slf.__obj, slf.__clsName, methodName, args);
          }
      }
  };
  // 为所有的对象添加__c的方法
  for (var method in _customMethods) {
    Object.defineProperty(Object.prototype, method, { value: _customMethods[method], configurable: false, enumerable: false })
  }

  // 调用OC的方法
  var _methodFunc = function(instance, clsName, methodName, args) {
    var selectorName = methodName;
    methodName = methodName.replace(/__/g, "-");
    selectorName = methodName.replace(/_/g, ":").replace(/-/g, "_");
    // 获取请求参数个数
    var marchArr = selectorName.match(/:/g);
    var numOfArgs = marchArr ? marchArr.length : 0;
    if (args.length > numOfArgs) 
    {
      selectorName += ":";  
    }

    var ret;
    if (instance) 
    {
      ret = _OC_callI(instance, selectorName, args);
    }
    else
    {
      ret = _OC_callC(clsName, selectorName, args);
    }
    return _formatOCToJS(ret);
  }

  /* 将OC对象转换为JS对象 */
  var _formatOCToJS = function(obj) {
    if (obj === undefined || obj === null) return;

    if (typeof obj == "object")
    {
      if (obj.__obj) return obj;
    }

    if (obj instanceof Array)
    {
      var ret = [];
      obj.forEach(function(o) {
        ret.push(_formatOCToJS(o))
      });  
      return ret;
    }

    return obj;
  };

  var _require = function (clsName) {
    if (!global[clsName]) {
      global[clsName] = {
        __clsName: clsName
      }
    }
    return global[clsName]
  }

  global.require = function () {
    var lastRequire
    for (var i = 0; i < arguments.length; i++) {
      arguments[i].split(',').forEach(function (clsName) {
        lastRequire = _require(clsName.trim())
      })
    }
    return lastRequire
  }

  global.defineClass = function(declaration, properties, instanceMethods, classMethods) {
    var newInstanceMethods = {}, newClassMethods = {}

    // 如果properties不是数组，表明第二个参数是个对象方法列表
    if (!(properties instanceof Array))
    {
      classMethods = instanceMethods;
      instanceMethods = properties;
      properties = null;
    }

    if (properties)
    {
      
    }

    // 取出类，防止类实现了某种协议
    var realClassName = declaration.split(':')[0].trim();


    _formatDefineMethods(instanceMethods, newInstanceMethods, realClassName);
    _formatDefineMethods(classMethods, newClassMethods, realClassName);

    var ret = _OC_defineClass(declaration, newInstanceMethods, newClassMethods);
    var clsName = ret['cls'];
    var superCls = ret['superCls'];


    _ocCls[clsName] = {
      instanceMethods:[],
      classMethods: []
    }

    // 如果父类存在的话，并且父类在_ocCls存在的话，就把父类的方法同时保存在子类中
    // if (superCls.length && _ocCls[superCls])
    // {
    //   for (var funcName in _ocCls[superCls].instanceMethods)
    //   {
    //     _ocCls[className].instanceMethods[funcName] = _ocCls[superCls].instanceMethods[funcName];
    //   }
    //   for (var funcName in _ocCls[superCls].classMethods) 
    //   {
    //     _ocCls[className].classMethods[funcName] = _ocCls[superCls].classMethods[funcName];
    //   }
    // }
    _setupJSMethod(clsName, instanceMethods, 1, realClassName);
    _setupJSMethod(clsName, classMethods, 0, realClassName);

    return require(clsName);
  };

  var _setupJSMethod = function(className, methods, isInstance, realClassName) {
    for (var name in methods) {
      var func = methods[name];
      if (isInstance) 
      {
        _ocCls[className].instanceMethods[name] = _wrapLocalMethod(name, func, realClassName);  
      }
      else
      {
        _ocCls[className].classMethods[name] = _wrapLocalMethod(name, func, realClassName);  
      }
    }
  };

  var _wrapLocalMethod = function(methodName, func, realClassName) {
    return function() {
      var lastSelf = global.self;
      global.self = this;
      this.__realClsName = realClassName;
      var ret = func.apply(this, arguments);
      global.self = lastSelf;
      return ret;
    }
  };

  /*  
    methods: 原方法列表
    newMethods: 新方法列表
    realClassName: 类名
  */
  var _formatDefineMethods = function(methods, newMethods, realClassName) {

    for (var methodName in methods) {
      
      // 如果不是方法实现，则返回
      if (!(methods[methodName] instanceof Function)) return;

      (function(){
        // 取出原方法的实现
        var originMethod = methods[methodName];

        newMethods[methodName] = [originMethod.length, function() {
          try {
          // 把OC传递过来的参数数组转JS
            var args = _formatOCToJS(Array.prototype.slice.call(arguments));
            var lastSelf = global.self;
            global.self = args[0];
            if (global.self)
                global.self.__realClsName = realClassName;
            // 默认第一个参数自己的类名，截取掉第一个
            args.slice(0, 1);
            var ret = originMethod.apply(originMethod, args);
            global.self = lastSelf;
            return ret;
          }
          catch(e) {
            console.log(e.message);
          };
        }];
      })();
    }

  };
  
  // JS不支持YES和NO的属性，所以分别设置1和0，传给OC
  global.YES = 1
  global.NO = 0
  
})()
  
