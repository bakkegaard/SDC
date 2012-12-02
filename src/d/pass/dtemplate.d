module d.pass.dtemplate;

import d.pass.base;
import d.pass.identifiable;
import d.pass.semantic;

import d.ast.declaration;
import d.ast.dtemplate;
import d.ast.expression;
import d.ast.type;

import sdc.location;

import std.algorithm;
import std.array;

final class TemplateInstancier {
	private SemanticPass pass;
	alias pass this;
	
	this(SemanticPass pass) {
		this.pass = pass;
	}
	
	auto instanciate(Location location, TemplateDeclaration tplDecl, TemplateArgument[] arguments) {
		tplDecl = cast(TemplateDeclaration) scheduler.require(pass, tplDecl);
		
		Declaration[] argDecls;
		uint i = 0;
		
		// XXX: have to put array once again.
		assert(tplDecl.parameters.length == arguments.length);
		string id = arguments.map!(delegate string(TemplateArgument arg) {
			auto identifiable = visit(arg);
			
			if(auto type = identifiable.asType()) {
				argDecls ~= new AliasDeclaration(arg.location, tplDecl.parameters[i++].name, type);
				
				return "T" ~ pass.typeMangler.visit(type);
			}
			
			assert(0, "Only type argument are supported.");
		}).array().join();
		
		return tplDecl.instances.get(id, {
			auto oldManglePrefix = this.manglePrefix;
			scope(exit) this.manglePrefix = oldManglePrefix;
			
			import std.conv;
			auto tplMangle = "__T" ~ to!string(tplDecl.name.length) ~ tplDecl.name ~ id ~ "Z";
			
			this.manglePrefix = tplDecl.mangle ~ to!string(tplMangle.length) ~ tplMangle;
			
			import d.pass.clone;
			auto clone = new ClonePass();
			auto members = tplDecl.declarations.map!(delegate Declaration(Declaration d) { return clone.visit(d); }).array();
			
			auto instance = new TemplateInstance(location, arguments, argDecls ~ members);
			
			import d.pass.dscope;
			auto scopePass = new ScopePass();
			instance = scopePass.visit(instance, tplDecl);
			
			// Update scope.
			auto oldScope = pass.currentScope;
			scope(exit) pass.currentScope = oldScope;
			
			pass.currentScope = instance.dscope;
			
			instance.declarations = cast(Declaration[]) pass.scheduler.schedule(pass, instance.declarations, d => pass.visit(d));
			
			return tplDecl.instances[id] = instance;
		}());
	}
	
	Identifiable visit(TemplateArgument arg) {
		return this.dispatch(arg);
	}
	
	Identifiable visit(TypeTemplateArgument arg) {
		return Identifiable(pass.visit(arg.type));
	}
	
	Identifiable visit(AmbiguousTemplateArgument arg) {
		if(auto type = pass.visit(arg.argument.type)) {
			return Identifiable(type);
		} else if(auto expression = pass.visit(arg.argument.expression)) {
			return Identifiable(expression);
		}
		
		assert(0, "Ambiguous can't be deambiguated.");
	}
}
