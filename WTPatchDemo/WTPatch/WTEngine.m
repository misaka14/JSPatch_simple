//
//  WTEngine.m
//  WTPatchDemo
//
//  Created by 无头骑士 GJ on 2018/10/11.
//  Copyright © 2018 无头骑士 GJ. All rights reserved.
//

#import "WTEngine.h"
#import <objc/message.h>

static JSContext *_context;
static NSRegularExpression* _regex;
static NSString *_regexStr = @"(?<!\\\\)\\.\\s*(\\w+)\\s*\\(";
static NSString *_replaceStr = @".__c(\"$1\")(";

// 保存了重写了哪些方法
static NSMutableDictionary *_JSOverideMethods;
static NSMutableDictionary *_JSMethodSignatureCache;

static void (^_exceptionBlock)(NSString *log) = ^void(NSString *log) {
    NSCAssert(NO, log);
};

@implementation WTBoxing


+ (instancetype)boxWeakObj:(id)obj
{
    WTBoxing *boxing = [WTBoxing new];
    boxing.weakObj = obj;
    return boxing;
}

- (id)unbox
{
    if (self.weakObj) return self.weakObj;
    
    return nil;
}


@end


@implementation WTEngine


+ (void)startEngine
{
    if (_context) return;
    
    JSContext *context = [[JSContext alloc] init];
    
    
    context[@"_OC_defineClass"] = ^(NSString *classDeclaration, JSValue *instanceMethods, JSValue *classMethods) {
        
        return [self defineClass: classDeclaration instanceMethods: instanceMethods classMethods: classMethods];
    };
    
    context[@"_OC_callC"] = ^id(NSString *className, NSString *selectorName, JSValue *arguments) {
        return callSelector(className, selectorName, arguments, nil);
    };

    
    context[@"_OC_callI"] = ^id(JSValue *obj, NSString *selectorName, JSValue *arguments) {
        return callSelector(nil, selectorName, arguments, obj);;
    };
    
    context[@"_OC_formatJSToOC"] = ^id(JSValue *obj) {
        return nil;
    };
    
    context[@"_OC_formatOCToJS"] = ^id(JSValue *obj) {
        return nil;
    };
    
    _context = context;
    
    
    
    NSString *path = [[NSBundle bundleForClass: [self class]] pathForResource: @"WTPatch" ofType: @"js"];
    
    if (!path) NSCAssert(NO, @"找不到WTPatch.js文件");
    
    NSData *data = [[NSData alloc] initWithContentsOfFile: path];
    NSString *patchJS = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    [_context evaluateScript: patchJS withSourceURL: [NSURL URLWithString: @"WTPatch.js"]];
}

+ (JSValue *)evaluateScript:(NSString *)script
{
    return [self _evaluateScript: script withSourceURL: [NSURL URLWithString: @"main.js"]];
}

+ (JSValue *)_evaluateScript:(NSString *)script withSourceURL:(NSURL *)resourceURL
{
    if (!script) return nil;
    
    if (!_regex) {
        _regex = [NSRegularExpression regularExpressionWithPattern: _regexStr options: 0 error: nil];
    }
    
    // 把demo.js的方法调用，替换成__c("方法名")
    NSString *formatedScript = [_regex stringByReplacingMatchesInString: script options: 0 range: NSMakeRange(0, script.length) withTemplate: _replaceStr];
    
    return [_context evaluateScript: formatedScript withSourceURL: resourceURL];
    
    return nil;
}

+ (NSDictionary *)defineClass:(NSString *)classDeclaration instanceMethods:(JSValue *)instanceMethods classMethods:(JSValue *)classMethods
{
    // 获取类对象
    Class cls = NSClassFromString(classDeclaration);
    NSString *superClassName = @"NSObject";
    if (!cls)
    {
        Class superCls = NSClassFromString(superClassName);
        cls = objc_allocateClassPair(superCls, classDeclaration.UTF8String, 0);
        objc_registerClassPair(cls);
    }
    
    // 遍历实例方法和类方法
    for (int i = 0; i < 2; i++)
    {
        BOOL isInstance = i == 0;
        
        JSValue *jsMethods = isInstance ? instanceMethods : classMethods;
        
        // 如果是类方法，就取出元类对象
        Class currentClass = isInstance ? cls: objc_getMetaClass(classDeclaration.UTF8String);
        
        // 取出方法字典
        NSDictionary *methodsDict = [jsMethods toDictionary];
        
        for (NSString *jsMethodName in methodsDict.allKeys) {
            
            JSValue *jsMethodArr = [jsMethods valueForProperty: jsMethodName];
            int numberOfArg = [jsMethodArr[0] toInt32];
            NSString *selectorName = [self convertJPSelectorString: jsMethodName];
            
            // 判断方法是否有参数
            if ([selectorName componentsSeparatedByString: @":"].count - 1 < numberOfArg)
            {
                selectorName = [selectorName stringByAppendingString: @":"];
            }
            
            JSValue *jsMethod = jsMethodArr[1];
            
            if (class_respondsToSelector(currentClass, NSSelectorFromString(selectorName)))
            {
                [self overrideMethod: currentClass selectorName: selectorName function: jsMethod isClassMethod: !isInstance typeDescription: NULL];
                
            }
            else
            {
                BOOL overrided = NO;
                if (!overrided)
                {
                    if (![[jsMethodName substringToIndex: 1] isEqualToString: @"_"])
                    {
                        NSMutableString *typeDescStr = [@"@@:" mutableCopy];
                        for (int i = 0; i < numberOfArg; i++)
                        {
                            [typeDescStr appendString: @"@"];
                        }
                        [self overrideMethod: currentClass selectorName: selectorName function: jsMethod isClassMethod: !isInstance typeDescription: [typeDescStr cStringUsingEncoding: NSUTF8StringEncoding]];
                    }
                }
            }
        }
    }
    
    
    
    
    return @{@"cls": classDeclaration, @"superCls": superClassName};
}

+ (void)overrideMethod:(Class)cls selectorName:(NSString *)selectorName function:(JSValue *)function isClassMethod:(BOOL)isClassMethod typeDescription:(const char *)typeDescription
{
    SEL selector = NSSelectorFromString(selectorName);
    
    if (!typeDescription)
    {
        Method method = class_getInstanceMethod(cls, selector);
        typeDescription = method_getTypeEncoding(method);
    }
    // 如果js编写的方法实现，已经实现了
    IMP originalIMP;
    if (class_respondsToSelector(cls, selector))
    {
        class_getMethodImplementation(cls, selector);
    }
    
    // 替换forwardInvocation的实现为WTForwardInvocation的实现
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)WTForwardInvocation)
    {
        class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)WTForwardInvocation, "v@:@");
    }
    
    // 把重写的方法保存全局的二维字典
    NSString *JPSelectorName = [NSString stringWithFormat:@"_JP%@", selectorName];
    [self _initJPOverrideMethods: cls];
    _JSOverideMethods[cls][JPSelectorName] = function;
    
    // 判断是否实现了forwardInvocation方法，如果实现，则替换
    // 相当于把所有的实现，都直接走消息转发流程，也就是forwardInvocation,由于上面
    // forwardInvocation 被替换成了JPForwardInvocation，所以直接走JPForwardInvocation函数
    class_replaceMethod(cls, selector, _objc_msgForward, typeDescription);
}

+ (void)_initJPOverrideMethods:(Class)cls
{
    if (!_JSOverideMethods)
    {
        _JSOverideMethods = [NSMutableDictionary dictionary];
    }
    
    if (!_JSOverideMethods[cls])
    {
        _JSOverideMethods[(id<NSCopying>)cls] = [NSMutableDictionary dictionary];
    }
}

+ (NSString *)convertJPSelectorString:(NSString *)selectorString
{
    NSString *tmpJSMethodName = [selectorString stringByReplacingOccurrencesOfString: @"__" withString: @"-"];
    NSString *selectorName = [tmpJSMethodName stringByReplacingOccurrencesOfString: @"_" withString: @":"];
    return [selectorName stringByReplacingOccurrencesOfString: @"-" withString: @"_"];
}

static void WTForwardInvocation(id slf, SEL _cmd, NSInvocation *invocation)
{
    NSMethodSignature *methodSignature = [invocation methodSignature];
    NSInteger numberOfArguments = [methodSignature numberOfArguments];
    NSString *selectorName = NSStringFromSelector(invocation.selector);
    NSString *JPSelectorName = [NSString stringWithFormat: @"_JP%@", selectorName];
    JSValue *jsFunc = getJSFunctionInObjectHierachy(slf, JPSelectorName);
    
    // 方法参数数组
    NSMutableArray *argList = [NSMutableArray array];
    // 第一个参数是相当于对象
    [argList addObject: [WTBoxing boxWeakObj: slf]];
    
    for (NSUInteger i = 2; i < numberOfArguments; i++)
    {
        const char *argumentType = [methodSignature getArgumentTypeAtIndex: i];
        
        switch (argumentType[0]) {
            case '@':
            {
                id arg;
                [invocation getArgument: &arg atIndex: i];
                [argList addObject: arg];
            }
                
                
                break;
                
            default:
                break;
        }
    }
    NSArray *params = _formatOCToJSList(argList);
    
    // 判断返回值
    char returnType[255];
    strcpy(returnType, [methodSignature methodReturnType]);
    switch (returnType[0]) {
            
        case '@':
        {
            JSValue *jsValue;
            jsValue = [jsFunc callWithArguments: params];
            
            id ret = formatJSToOC(jsValue);
            if (!ret)
            {
                ret = nil;
            }
            [invocation setReturnValue: &ret];
        }
            break;
            
        case 'v':
        {
            JSValue *jsValue;
            jsValue = [jsFunc callWithArguments: params];
        }
            break;
            
        default:
            break;
    }
}

static id _formatOCToJSList(NSArray *list)
{
    NSMutableArray *arr = [NSMutableArray array];
    for (id obj in list)
    {
        [arr addObject: formatOCToJS(obj)];
    }
    return arr;
}

static id formatOCToJS(id obj)
{
    return _wrapObj(obj);
}

static id formatJSToOC(JSValue *jsValue)
{
    id obj = [jsValue toObject];
    
    if (!obj) {
        return nil;
    }
    
    if ([obj isKindOfClass: [WTBoxing class]])
    {
        return [obj unbox];
    }
    
    if ([obj isKindOfClass: [NSArray class]])
    {
        NSMutableArray *newArray = [NSMutableArray array];
        for (NSUInteger i = 0; i < [(NSArray *)obj count]; i++)
        {
            [newArray addObject: formatJSToOC(jsValue[i])];
        }
        return newArray;
    }
    
    if ([obj isKindOfClass: [NSDictionary class]])
    {
        if (obj[@"__obj"])
        {
            id ocObj = [obj objectForKey: @"__obj"];
            return ocObj;
        }
    }
    
    return obj;
}

static NSDictionary *_wrapObj(id obj) {
    if (!obj)
    {
        return @{@"__isNil": @(YES)};
    }
    
    NSString *clsName;
    if ([obj isKindOfClass: [WTBoxing class]])
    {
        WTBoxing *boxing = (WTBoxing *)obj;
        clsName = NSStringFromClass([[boxing unbox] class]);
    }
    else
    {
        clsName = NSStringFromClass([obj class]);
        
    }
    
    NSDictionary *dict = @{@"__obj": obj, @"__clsName": clsName};
    return dict;
}

static JSValue *getJSFunctionInObjectHierachy(id slf, NSString *selectorName)
{
    Class cls = object_getClass(slf);
    
    JSValue *func = _JSOverideMethods[cls][selectorName];
    
    while (!func)
    {
        cls = class_getSuperclass(cls);
        if (!cls) return nil;
        
        func = _JSOverideMethods[cls][selectorName];
    }
    return func;
}

/**
 JS函数内的方法，回调到这里

 @param className 类名
 @param selectorName 方法名
 @param arguments 参数
 @param instance 实例对象
 @return 返回值
 */
static id callSelector(NSString *className, NSString *selectorName, JSValue *arguments, JSValue *instance)
{
    // 取出类名
    NSString *realClsName = [[instance valueForProperty: @"__realClsName"] toString];
    
    // 把JS对象转换成OC对象
    if (instance)
    {
        // 把JS对象转换成OC的实例对象
        instance = formatJSToOC(instance);
    }
    
    
    // 把JS的参数数组转换成OC数组
    id argumentObj = formatJSToOC(arguments);
    
    // 获取类对象
    Class cls = instance ? [instance class] : NSClassFromString(className);
    
    // 获取要消息转发的方法
    SEL selector = NSSelectorFromString(selectorName);
    
    NSMutableArray *_markArray;
    NSInvocation *invocation;
    
    NSMethodSignature *methodSignature;
    if (!_JSMethodSignatureCache)
    {
        _JSMethodSignatureCache = [[NSMutableDictionary alloc] init];
    }
    
    if (instance)
    {
#warning 加锁
        if (_JSMethodSignatureCache[cls])
        {
            _JSMethodSignatureCache[(id<NSCopying>)cls] = [NSMutableDictionary dictionary];
        }
        methodSignature = _JSMethodSignatureCache[cls][selectorName];
        
        if (!methodSignature)
        {
            methodSignature = [cls instanceMethodSignatureForSelector: selector];
            _JSMethodSignatureCache[cls][selectorName] = methodSignature;
        }
#warning 解锁
        invocation = [NSInvocation invocationWithMethodSignature: methodSignature];
        // 需要调用哪个对象的方法
        invocation.target = instance;
    }
    else
    {
        methodSignature = [cls methodSignatureForSelector: selector];
        // 方法签名
        invocation = [NSInvocation invocationWithMethodSignature: methodSignature];
        // 调用的对象
        invocation.target = cls;
    }
    // 需要调用哪个方法
    invocation.selector = selector;
    
    // 获取参数的个数
    NSUInteger numberOfArguments = methodSignature.numberOfArguments;
    for (NSUInteger i = 2; i < numberOfArguments; i++)
    {
        const char *argumentType = [methodSignature getArgumentTypeAtIndex: i];
        id valObj = argumentObj[i - 2];
        
        [invocation setArgument: &valObj atIndex: i];
    }
    
    // 调用方法
    [invocation invoke];
    
    // 获取返回值
    char returnType[255];
    strcpy(returnType, [methodSignature methodReturnType]);
    
    id returnValue;
    // 如果返回的参数不为空的话
    if (strncmp(returnType, "v", 1) != 0)
    {
        // 如果返回的参数为对象的话
        if (strncmp(returnType, "@", 1) == 0)
        {
            void *result;
            [invocation getReturnValue: &result];
            
//            if ([selectorName isEqualToString: @"alloc"])
            {
                returnValue = (__bridge id)(result);
            }
            return formatOCToJS(returnValue);
        }
    }
    return nil;
}


@end

