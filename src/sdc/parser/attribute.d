/**
 * Copyright 2010 Bernard Helyer
 * This file is part of SDC. SDC is licensed under the GPL.
 * See LICENCE or sdc.d for more details.
 */
module sdc.parser.attribute;

import std.string;

import sdc.util;
import sdc.compilererror;
import sdc.tokenstream;
import sdc.parser.base;
import sdc.parser.expression;
import sdc.ast.attribute;


AttributeSpecifier parseAttributeSpecifier(TokenStream tstream)
{
    auto attributeSpecifier = new AttributeSpecifier();
    attributeSpecifier.location = tstream.peek.location;
    attributeSpecifier.attribute = parseAttribute(tstream);
    if (tstream.peek.type == TokenType.Colon) {
        match(tstream, TokenType.Colon);
    } else {
        attributeSpecifier.declarationBlock = parseDeclarationBlock(tstream);
    }
    return attributeSpecifier;
}


Attribute parseAttribute(TokenStream tstream)
{
    auto attribute = new Attribute();
    attribute.location = tstream.peek.location;
    
    Attribute parseExtern()
    {
        match(tstream, TokenType.Extern);
        if (tstream.peek.type != TokenType.OpenParen) {
            goto err;
        }
        match(tstream, TokenType.OpenParen);
        if (tstream.peek.type != TokenType.Identifier) {
            goto err;
        }
        switch (tstream.peek.value) {
        case "C":
            attribute.type = AttributeType.ExternC;
            break;
        case "C++":
            attribute.type = AttributeType.ExternCPlusPlus;
            break;
        case "D":
            attribute.type = AttributeType.ExternD;
            break;
        case "Windows":
            attribute.type = AttributeType.ExternWindows;
            break;
        case "Pascal":
            attribute.type = AttributeType.ExternPascal;
            break;
        case "System":;
            attribute.type = AttributeType.ExternSystem;
            break;
        default:
            error(tstream.peek.location, "unsupported extern linkage. Supported linkages are C, C++, D, Windows, Pascal, and System.");
        }
        match(tstream, TokenType.Identifier);
        match(tstream, TokenType.CloseParen);
        
        return attribute;
        
    err:
        error(tstream.peek.location, "ICE: only linkage style extern supported.");
        assert(false);
    }
    
    switch (tstream.peek.type) {
    case TokenType.Deprecated: case TokenType.Private:
    case TokenType.Package: case TokenType.Protected:
    case TokenType.Public: case TokenType.Export:
    case TokenType.Static: case TokenType.Final:
    case TokenType.Override: case TokenType.Abstract:
    case TokenType.Const: case TokenType.Auto:
    case TokenType.Scope: case TokenType.__Gshared:
    case TokenType.Shared: case TokenType.Immutable:
    case TokenType.Inout: case TokenType.atDisable:
        // Simple keyword attribute.
        attribute.type = cast(AttributeType) tstream.peek.type;
        tstream.getToken();
        break;
    case TokenType.Align:
        attribute.type = AttributeType.Align;
        attribute.node = parseAlignAttribute(tstream);
        break;
    case TokenType.Pragma:
        break;
    case TokenType.Extern:
        return parseExtern();
    default:
        error(tstream.peek.location, format("bad attribute '%s'.", tokenToString[tstream.peek.type]));
        assert(false);
    }
    
    return attribute;
}


bool startsLikeAttribute(TokenStream tstream)
{
    return contains(ATTRIBUTE_KEYWORDS, tstream.peek.type);
}


AlignAttribute parseAlignAttribute(TokenStream tstream)
{
    auto alignAttribute = new AlignAttribute();
    alignAttribute.location = tstream.peek.location;
    match(tstream, TokenType.Align);
    if (tstream.peek.type == TokenType.OpenParen) {
        match(tstream, TokenType.OpenParen);
        alignAttribute.integerLiteral = parseIntegerLiteral(tstream);
        match(tstream, TokenType.CloseParen);
    }
    return alignAttribute;
}


PragmaAttribute parsePragmaAttribute(TokenStream tstream)
{
    auto pragmaAttribute = new PragmaAttribute();
    pragmaAttribute.location = tstream.peek.location;
    match(tstream, TokenType.Pragma);
    match(tstream, TokenType.OpenParen);
    pragmaAttribute.identifier = parseIdentifier(tstream);
    if (tstream.peek.type == TokenType.Comma) {
        match(tstream, TokenType.Comma);
        pragmaAttribute.argumentList = parseArgumentList(tstream);
    }
    match(tstream, TokenType.CloseParen);
    return pragmaAttribute;
}

DeclarationBlock parseDeclarationBlock(TokenStream tstream)
{
    auto declarationBlock = new DeclarationBlock();
    declarationBlock.location = tstream.peek.location;
    
    if (tstream.peek.type == TokenType.OpenBrace) {
        match(tstream, TokenType.OpenBrace);
        while (tstream.peek.type != TokenType.CloseBrace) {
            declarationBlock.declarationDefinitions ~= parseDeclarationDefinition(tstream);
        }
        match(tstream, TokenType.CloseBrace);
    } else {
        declarationBlock.declarationDefinitions ~= parseDeclarationDefinition(tstream);
    }
    
    return declarationBlock;
}