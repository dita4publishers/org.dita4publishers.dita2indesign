<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
      xmlns:xs="http://www.w3.org/2001/XMLSchema"
      xmlns:local="urn:local-functions"
      xmlns:relpath="http://dita2indesign/functions/relpath"
      xmlns:df="http://dita2indesign.org/dita/functions"
      exclude-result-prefixes="xs local df relpath"
      version="2.0">
  
  <!-- =====================================================================
       DITA to InDesign Transform
       
       Generates InCopy articles (.incx) and/or InDesign INX files from 
       an input map or a single topic.
    
       Copyright (c) 2008, 2010 DITA2InDesign project
    
    Parameters:
    
    chunkStrategy: Indicates how result topics are to be organized into
                   ICML files. Provides some basic options as an alternative
                   to creating custom overrides.
                   
                   Values are:
                   
                   - perTopicDoc  — Each topic document ("chunk" in the DITA sense)
                                    results in a new ICML file. This is the default.
                                    
                   - perChapter   - Each top-level topic in the map structure generates
                                    a new ICML file. For BookMap and PubMap, part and
                                    chapter topicrefs result in new chunks. 
                                    
                   - perMap       - The entire map results in a single ICML file
                   
    sidebarChunkStrategy: Indicates how to handle sidebar topics in the result ICML:
    
                   - normal   - Handled like any other topic. The active chunkStrategy 
                                is used.
                                
                   - toFile   - Generate a new ICML file for each sidebar topic
                   
                   - toAnchoredFrame - Put the sidebar in an anchored frame. If
                                       there is a D4P sidebar anchor to the sidebar
                                       it is anchored at that point, otherwise it
                                       is anchored at the point where it occurs in the
                                       main topic sequence.

    
    debug - Turns template debugging on and off: 
    
    'true' - Turns debugging on
    'false' - Turns it off (the default)
    =====================================================================-->
  
  <xsl:import href="../../org.dita-community.common.xslt/xsl/dita-support-lib.xsl"/>
  <xsl:import href="../../org.dita-community.common.xslt/xsl/relpath_util.xsl"/>
  
  <xsl:include href="topic2icmlImpl.xsl"/>
  <xsl:include href="generateResultDocs.xsl"/>
  
  <xsl:param name="WORKDIR" as="xs:string" select="''"/>
  <xsl:param name="PATH2PROJ" as="xs:string" select="''"/>
  <xsl:param name="KEYREF-FILE" as="xs:string" select="''"/>
  

  <xsl:param name="platform" select="'unknown'" as="xs:string"/>
  <xsl:param name="outdir" select="./indesign"/>
  <xsl:param name="tempdir" select="./temp"/>
  <xsl:param name="titleOnlyTopicClassSpec" select="'- topic/topic '" as="xs:string"/>
  
  <xsl:param name="titleOnlyTopicTitleClassSpec" select="'- topic/title '" as="xs:string"/>

  <xsl:param name="chunkStrategy" select="'perTopicDoc'"/>
  
  <xsl:param name="sidebarChunkStrategy" select="'normal'"/>
  
  <xsl:param name="debug" select="'false'"/>
  <xsl:variable name="debugBoolean" 
    select="matches($debug,'true|yes|1|on', 'i')" as="xs:boolean"
  />
  
  <!-- For output it is essential that there be no extraneous whitespace.
    There is no need for a DOCTYPE declaration as all attributes
    will have been instantiated by this process. Validation is neither
    useful nor meaningful at this point in the process.
  -->
  <xsl:output encoding="UTF-8"
    indent="no"
    method="xml"
  />
  
  <xsl:template match="/">
    <xsl:apply-templates select="." mode="report-parameters"/>
    <xsl:apply-templates>
      <xsl:with-param name="articleType" select="'topic'" as="xs:string" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template name="report-parameters" match="*" mode="report-parameters">
    <xsl:param name="effectiveCoverGraphicUri" select="''" as="xs:string" tunnel="yes"/>
    <xsl:message> 
      ==========================================
      Plugin version: ^version^ - build ^buildnumber^ at ^timestamp^
      
      Parameters:
      
      + outdir          = "<xsl:sequence select="$outdir"/>"
      + tempdir         = "<xsl:sequence select="$tempdir"/>"
      + linksPath       = "<xsl:sequence select="$linksPath"/>"
      + chunkStrategy   = "<xsl:sequence select="$chunkStrategy"/>"
      + sidebarChunkStrategy = "<xsl:sequence select="$sidebarChunkStrategy"/>"
      
      + WORKDIR         = "<xsl:sequence select="$WORKDIR"/>"
      + PATH2PROJ       = "<xsl:sequence select="$PATH2PROJ"/>"
      + KEYREF-FILE     = "<xsl:sequence select="$KEYREF-FILE"/>"
      + debug           = "<xsl:sequence select="$debug"/>"
      
      Global Variables:
      
      + platform         = "<xsl:sequence select="$platform"/>"
      + debugBoolean     = "<xsl:sequence select="$debugBoolean"/>"
      
      ==========================================
    </xsl:message>
  </xsl:template>
  
  <xsl:template match="/*[df:class(., 'map/map')]">
    <!-- The map-level processing is done in two 
         stages:
         
         Stage 1: Processes the entire map and produces a
                  single result XML structure that represents
                  all ICML articles to be generated.
                  
                  Each article is bounded by a local:result-document
                  element, which is the same as xsl:result-document 
                  but in the local namespace. The result documents
                  may be nested.
                  
                  This processing is done in the default mode.
                  
                  NOTE: the mode "result-docs" is now mapped to
                        the default mode for backward compatibility.
                  
         Stage 2: The result of stage 1 is processed to generate all
                  the result documents.
                  
      -->
    <xsl:message> + [INFO] Stage 1: Processing map to construct intermediate ICML data file with result documents marked.</xsl:message>
    <xsl:variable name="icmlDataWithResultDocsMarked" as="node()*">
      <xsl:choose>
        <xsl:when test="matches($chunkStrategy, 'perMap', 'i')">
          <xsl:variable name="articleIcmlData" as="node()*">
            <xsl:apply-templates mode="process-map"/>
          </xsl:variable>
          <local:result-document 
            href="{relpath:newFile($outputPath, local:getArticleUrlForTopic(.))}"
          >
            <xsl:call-template name="makeInCopyArticle">
              <!-- content parameter is source elements to be processed
                   in normal model, which we don't want.
                -->
              <xsl:with-param name="content" select="()" as="node()*"/>
              <!-- Leading paragraphs are ICML paragraphs. -->
              <xsl:with-param name="leadingParagraphs" 
                select="$articleIcmlData" as="node()*"
              />
            </xsl:call-template>
          </local:result-document>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="process-map"/>
        </xsl:otherwise>
      </xsl:choose>
      
    </xsl:variable>
    <xsl:message> + [INFO] Stage 2: Generating result documents</xsl:message>
    <xsl:apply-templates select="$icmlDataWithResultDocsMarked"
      mode="generate-result-docs"/>
  </xsl:template>

  <xsl:template mode="process-map" match="*[df:class(.,'map/map')]">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template mode="process-map" match="*[df:class(., 'map/topicref')][@href]">
    <!-- Handle references to topics -->
    <xsl:variable name="targetTopic" select="df:resolveTopicRef(.)" as="element()?"/>
    <xsl:choose>
      <xsl:when test="not($targetTopic)">
        <xsl:message> + [ERROR] Failed to resolve topicref to URL "<xsl:sequence select="string(@href)"/>".</xsl:message>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message> + [INFO] Processing topic <xsl:sequence select="document-uri(root($targetTopic))"/>...</xsl:message>
        <xsl:apply-templates select="$targetTopic">
          <!-- Give the topic access to its referencing topicref so it can know where it 
               lives in the map structure, what the topicref properties were, etc.
            -->
          <xsl:with-param name="topicref" as="element()" tunnel="yes" select="."/>
          <!-- If the chunk strategy is perMap then the chunk has already
               been established.
            -->
          <xsl:with-param name="isChunkRoot" as="xs:boolean" tunnel="yes"
            select="not(matches($chunkStrategy, '^perMap$', 'i'))"
          />
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
    
    <!-- NOTE: subordinate topicrefs are handled in the template for topics so
               that topics can implement automatic chunking of nested topics
               to single ICML files.
      -->
  </xsl:template>
  
  <xsl:template mode="process-map" 
    match="*[df:class(.,'map/topicref')]
    [not(@href) and 
     df:hasSpecifiedNavtitle(.)]">
    <!-- Handle topicrefs with only navtitles -->
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template mode="process-map"
    match="*[df:class(.,'map/topicref')]
    [not(@href) and 
     not(df:hasSpecifiedNavtitle(.))]">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template 
    match="
    *[df:class(.,'topic/title')] |
    *[df:class(.,'map/topicmeta')]
    " 
    mode="process-map"/>  
  
  <xsl:template match="text()" mode="process-map"/>  
  <!-- Suppress all text within the map: there should be no output 
    resulting from the input map itself.
  -->
  
  <xsl:template mode="process-map" match="*" priority="-1">
    <xsl:message> + [WARNING] (process-map mode): Unhandled element <xsl:sequence select="name(..)"/>/<xsl:sequence select="name(.)"/></xsl:message>
  </xsl:template>
  
  <!-- Evaluates the context topic and its context against the
       chunk-control parameters to determine if the topic should
       start a new chunk.
    -->
  <xsl:function name="local:isChunkRoot" as="xs:boolean">    
    <xsl:param name="context" as="element()"/><!-- Topicref element -->
    <xsl:param name="topicref" as="element()"/><!-- Topicref to the topic 
                                                    (or its nearest ancestor topic) -->
    
    <xsl:variable name="result" as="xs:boolean"
        select="(matches($chunkStrategy, 'perTopicDoc', 'i') and
                 not($context/parent::*[df:class(., 'topic/topic')])) or
                (matches($chunkStrategy, 'perChapter', 'i') and
                 not($context/parent::*[df:class(., 'topic/topic')]) and
                 ((count($topicref/ancestor::*[df:isTopicRef(.)]) = 0) or
                  (contains($topicref/@class, '/part ') or 
                   contains($topicref/@class, '/chapter ')))) or
                ((df:class($context, 'sidebar/sidebar') or
                  contains($topicref/@class, '/sidebar ')) and
                  matches($sidebarChunkStrategy, 'toFile', 'i'))
          "
      />
    <xsl:sequence select="$result"/>
  </xsl:function>
  
</xsl:stylesheet>
