import haxe.macro.Expr;
import haxe.macro.Context;
class Test{
    public static function main(){
        trace('hello world!');

        wrap(function(_, f: String, g: String, args, _, penul: String, _, last: String) {
          trace(args);
        });
        /** generates:

         		Reflect.makeVarArgs(function(__args:Array<Dynamic>) {
              var f = __args[1];
              var g = __args[2];
              var args = __args.slice(3, -4);
              var __rest = __args.splice(-4, 4);
              var penul = __rest[1];
              var last = __rest[3];
              haxe.Log.trace(args, {fileName : "Test.hx", lineNumber : 8, className : "Test", methodName : "main"});
            });

        */
    }

    public static macro function wrap(fnExpr: Expr) {
      switch (fnExpr.expr) {
        case EFunction(_name, fn):
          var exprs:Array<Expr> = [];
          var l = fn.args.length; // total number of args
          var seenSplice = false;
          var spliceI = 0;
          for (i in 0...l) {
            var param = fn.args[i];
            var name = param.name;
            var type = param.type;

            if (name == "_") {
              if (seenSplice) spliceI++;
              continue;
            }

            if (seenSplice) {

              if (name == "args")
                return Context.error("Cannot splice twice", fnExpr.pos);
              else if (param.type == null)
                exprs.push(macro var $name = __rest[$v{spliceI}]);
              else
                exprs.push(macro var $name: $type = __rest[$v{spliceI}]);
              spliceI++;

            } else {

              if (param.name == "args") {
                var diff = l - 1 - i;
                exprs.push(macro var $name = __args.slice($v{i}, $v{-diff}));
                exprs.push(macro var __rest = __args.splice($v{-diff}, $v{diff}));
                seenSplice = true;
              } else if (param.type == null)
                exprs.push(macro var $name = __args[$v{i}]);
              else
                exprs.push(macro var $name: $type = __args[$v{i}]);

            }
          }
          if (fn.expr != null)
            exprs.push(fn.expr);
          var body = macro Reflect.makeVarArgs(function (__args) {
            $b{exprs};
          });
          return body;

        default:
          return Context.error("Invalid type passed", fnExpr.pos);
      }
    }
}
