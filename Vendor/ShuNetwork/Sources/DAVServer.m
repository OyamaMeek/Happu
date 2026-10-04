#import "HTTPServerInternal.h"
@import libxml2;

static void Element(xmlTextWriterPtr writer, NSString *name, NSString *value) {
    xmlTextWriterWriteElement(writer, BAD_CAST name.UTF8String, BAD_CAST value.UTF8String);
}
static GCDWebServerResponse *Properties(GCDWebServerRequest *request, ShuFileAccess *access, NSString *path, NSData *body) {
    NSString *depth = request.headers[@"Depth"] ?: @"infinity";
    if (![depth isEqual:@"0"] && ![depth isEqual:@"1"]) {
        GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithText:@"<?xml version=\"1.0\"?><D:error xmlns:D=\"DAV:\"><D:propfind-finite-depth/></D:error>"];
        response.statusCode = 403; response.contentType = @"application/xml; charset=utf-8"; return response;
    }
    NSArray *supported = @[@"displayname", @"resourcetype", @"getcontentlength", @"getlastmodified"];
    NSMutableArray *requested = [NSMutableArray new]; BOOL namesOnly = NO, defaultProperties = !body.length;
    if (body.length) {
        xmlDocPtr doc = xmlReadMemory(body.bytes, (int)body.length, NULL, NULL, XML_PARSE_NONET | XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
        xmlNodePtr root = doc ? xmlDocGetRootElement(doc) : NULL;
        BOOL valid = doc && !doc->intSubset && !doc->extSubset && root && xmlStrEqual(root->name, BAD_CAST "propfind") && root->ns && xmlStrEqual(root->ns->href, BAD_CAST "DAV:");
        int selections = 0;
        if (valid) for (xmlNodePtr node = root->children; node; node = node->next) {
            if (node->type == XML_TEXT_NODE && xmlIsBlankNode(node)) continue;
            if (node->type != XML_ELEMENT_NODE || !node->ns || !xmlStrEqual(node->ns->href, BAD_CAST "DAV:")) { valid = NO; break; }
            selections++;
            if (xmlStrEqual(node->name, BAD_CAST "prop")) {
                for (xmlNodePtr property = node->children; property; property = property->next) {
                    if (property->type == XML_TEXT_NODE && xmlIsBlankNode(property)) continue;
                    if (property->type != XML_ELEMENT_NODE || !property->ns || !property->ns->href) { valid = NO; break; }
                    [requested addObject:@{ @"name": @( (const char *)property->name), @"namespace": @((const char *)property->ns->href) }];
                }
            } else if (xmlStrEqual(node->name, BAD_CAST "propname")) { namesOnly = YES; defaultProperties = YES; }
            else if (xmlStrEqual(node->name, BAD_CAST "allprop")) defaultProperties = YES;
            else valid = NO;
        }
        valid = valid && selections == 1;
        if (doc) xmlFreeDoc(doc);
        if (!valid) return ShuErrorResponse(ShuError(400, @"PROPFIND XML 无效或包含 DTD。"));
    }
    if (defaultProperties) for (NSString *name in supported) [requested addObject:@{@"name":name, @"namespace":@"DAV:"}];
    NSError *error; NSDictionary *metadata = [access metadataAtRelativePath:path error:&error];
    if (!metadata) return ShuErrorResponse(error);
    NSMutableArray *items = [NSMutableArray arrayWithObject:@{@"path":path, @"metadata":metadata}];
    if ([depth isEqual:@"1"] && [metadata[@"isDirectory"] boolValue]) {
        NSArray *children = [access listAtRelativePath:path error:&error];
        if (!children) return ShuErrorResponse(error);
        for (NSDictionary *child in children) [items addObject:@{@"path": path.length ? [path stringByAppendingPathComponent:child[@"name"]] : child[@"name"], @"metadata":child}];
    }
    xmlBufferPtr buffer = xmlBufferCreate(); xmlTextWriterPtr writer = xmlNewTextWriterMemory(buffer, 0);
    if (!writer) { if (buffer) xmlBufferFree(buffer); return ShuErrorResponse(ShuError(500, @"无法生成 XML。")); }
    xmlTextWriterStartDocument(writer, NULL, "UTF-8", NULL);
    xmlTextWriterStartElement(writer, BAD_CAST "D:multistatus"); xmlTextWriterWriteAttribute(writer, BAD_CAST "xmlns:D", BAD_CAST "DAV:");
    NSDateFormatter *formatter = [NSDateFormatter new]; formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0]; formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
    NSMutableCharacterSet *allowed = [NSCharacterSet.alphanumericCharacterSet mutableCopy]; [allowed addCharactersInString:@"-._~"];
    for (NSDictionary *item in items) {
        NSDictionary *info = item[@"metadata"]; BOOL directory = [info[@"isDirectory"] boolValue];
        NSMutableArray *segments = [NSMutableArray new];
        for (NSString *segment in [item[@"path"] componentsSeparatedByString:@"/"]) if (segment.length) [segments addObject:[segment stringByAddingPercentEncodingWithAllowedCharacters:allowed]];
        NSString *href = [@"/" stringByAppendingString:[segments componentsJoinedByString:@"/"]]; if (directory && ![href hasSuffix:@"/"]) href = [href stringByAppendingString:@"/"];
        xmlTextWriterStartElement(writer, BAD_CAST "D:response"); Element(writer, @"D:href", href);
        for (NSNumber *knownGroup in @[@YES, @NO]) {
            NSMutableArray *properties = [NSMutableArray new];
            for (NSDictionary *property in requested) {
                BOOL known = [property[@"namespace"] isEqual:@"DAV:"] && [supported containsObject:property[@"name"]];
                if (known == knownGroup.boolValue) [properties addObject:property];
            }
            if (!properties.count && (requested.count || !knownGroup.boolValue)) continue;
            xmlTextWriterStartElement(writer, BAD_CAST "D:propstat"); xmlTextWriterStartElement(writer, BAD_CAST "D:prop");
            for (NSDictionary *property in properties) {
                NSString *name = property[@"name"];
                xmlTextWriterStartElementNS(writer, BAD_CAST "P", BAD_CAST name.UTF8String, BAD_CAST [property[@"namespace"] UTF8String]);
                if (knownGroup.boolValue && !namesOnly) {
                    if ([name isEqual:@"resourcetype"]) { if (directory) xmlTextWriterWriteElement(writer, BAD_CAST "D:collection", NULL); }
                    else {
                        NSString *value = [name isEqual:@"displayname"] ? info[@"name"] : ([name isEqual:@"getcontentlength"] ? (directory ? @"0" : [info[@"size"] stringValue]) : [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[info[@"modified"] doubleValue]]]);
                        xmlTextWriterWriteString(writer, BAD_CAST value.UTF8String);
                    }
                }
                xmlTextWriterEndElement(writer);
            }
            xmlTextWriterEndElement(writer); Element(writer, @"D:status", knownGroup.boolValue ? @"HTTP/1.1 200 OK" : @"HTTP/1.1 404 Not Found"); xmlTextWriterEndElement(writer);
        }
        xmlTextWriterEndElement(writer);
    }
    xmlTextWriterEndElement(writer); xmlTextWriterEndDocument(writer); xmlFreeTextWriter(writer);
    NSData *data = [NSData dataWithBytes:buffer->content length:buffer->use]; xmlBufferFree(buffer);
    GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithData:data contentType:@"application/xml; charset=utf-8"]; response.statusCode = 207; return response;
}
GCDWebServerResponse *ShuDAVResponse(GCDWebServerRequest *request, ShuFileAccess *access, NSString *path, NSData *body) {
    NSString *method = request.method; NSError *error;
    if ([method isEqual:@"OPTIONS"]) {
        GCDWebServerResponse *response = [GCDWebServerResponse responseWithStatusCode:200];
        [response setValue:@"OPTIONS, GET, HEAD, PUT, DELETE, MKCOL, PROPFIND, COPY, MOVE" forAdditionalHeader:@"Allow"]; return response;
    }
    if ([method isEqual:@"PROPFIND"]) return Properties(request, access, path, body);
    if ([method isEqual:@"GET"]) {
        if (request.headers[@"Range"] && !request.hasByteRange) return ShuErrorResponse(ShuError(416, @"下载范围无效。"));
        int fd = [access openRegularFileAtRelativePath:path error:&error];
        if (fd < 0) return ShuErrorResponse(error);
        return [[GCDWebServerFileResponse alloc] initWithFileDescriptor:fd filename:path byteRange:request.byteRange] ?: ShuErrorResponse(ShuError(416, @"下载范围超出文件。"));
    }
    if ([method isEqual:@"MKCOL"]) {
        if (body.length) return ShuErrorResponse(ShuError(415, @"MKCOL 不接受请求体。"));
        return [access createDirectoryAtRelativePath:path error:&error] ? [GCDWebServerResponse responseWithStatusCode:201] : ShuErrorResponse(error);
    }
    if ([method isEqual:@"DELETE"]) return [access removeItemAtRelativePath:path error:&error] ? [GCDWebServerResponse responseWithStatusCode:204] : ShuErrorResponse(error);
    if ([method isEqual:@"COPY"] || [method isEqual:@"MOVE"]) {
        NSString *value = request.headers[@"Destination"];
        NSURLComponents *destination = value ? [NSURLComponents componentsWithString:value] : nil;
        if (!ShuMatchesServerURL(destination, request) || destination.query || destination.fragment) return ShuErrorResponse(ShuError(403, @"Destination 必须属于当前共享服务。"));
        NSString *target = ShuRelativePath(destination.URL, @"/", &error);
        if (!target) return ShuErrorResponse(error);
        if (!path.length || !target.length) return ShuErrorResponse(ShuError(403, @"不允许复制或移动共享根目录。"));
        if ([path isEqual:target]) return ShuErrorResponse(ShuError(409, @"源与目标相同。"));
        NSString *overwrite = request.headers[@"Overwrite"] ?: @"T";
        if (![overwrite isEqual:@"T"] && ![overwrite isEqual:@"F"]) return ShuErrorResponse(ShuError(400, @"Overwrite 只能是 T 或 F。"));
        NSString *depth = request.headers[@"Depth"] ?: @"infinity";
        BOOL move = [method isEqual:@"MOVE"];
        if (![depth isEqual:@"infinity"] && (move || ![depth isEqual:@"0"])) return ShuErrorResponse(ShuError(400, @"此方法的 Depth 无效。"));
        BOOL success;
        if (!move && [depth isEqual:@"0"]) {
            NSDictionary *metadata = [access metadataAtRelativePath:path error:&error];
            if (!metadata) return ShuErrorResponse(error);
            success = [metadata[@"isDirectory"] boolValue] ? [access createDirectoryAtRelativePath:target error:&error] : [access copyItemAtRelativePath:path toRelativePath:target move:NO error:&error];
        } else success = [access copyItemAtRelativePath:path toRelativePath:target move:move error:&error];
        if (success) return [GCDWebServerResponse responseWithStatusCode:201];
        if (error.code == 409 && [overwrite isEqual:@"F"]) error = ShuError(412, @"目标已存在，未覆盖。" );
        return ShuErrorResponse(error);
    }
    return ShuErrorResponse(ShuError(501, @"此 WebDAV 方法尚不支持。"));
}
