<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
      xmlns:xs="http://www.w3.org/2001/XMLSchema"
      xmlns:df="http://dita2indesign.org/dita/functions"
      xmlns:ctbl="http//dita2indesign.org/functions/cals-table-to-inx-mapping"
      xmlns:incxgen="http//dita2indesign.org/functions/incx-generation"
      xmlns:e2s="http//dita2indesign.org/functions/element-to-style-mapping"
      xmlns:relpath="http://dita2indesign/functions/relpath"
      exclude-result-prefixes="xs df ctbl incxgen e2s relpath"
      version="2.0">
  
  <!-- CALS table to IDML table 
    
    Generates InDesign IDML tables from DITA CALS tables.
    Implements the "tables" mode.
    
    Copyright (c) 2011, 2014 DITA for Publishers
    
  -->
 
 
<!-- 
  Required modules: 
  <xsl:import href="lib/icml_generation_util.xsl"/>
  <xsl:import href="elem2styleMapper.xsl"/>
  -->
  <xsl:template match="*[df:class(.,'topic/table')]" priority="20">
    <xsl:text>&#x0a;</xsl:text>
    <xsl:if test="*[df:class(., 'topic/title')]">
      <xsl:call-template name="makeTableCaption">
        <xsl:with-param name="caption" select="*[df:class(., 'topic/title')]" as="node()*"/>
      </xsl:call-template>
    </xsl:if>
    <xsl:apply-templates select="*[df:class(., 'topic/tgroup')]"/>
  </xsl:template>
  
  <xsl:template match="*[df:class(., 'topic/tgroup')]">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    
    <xsl:variable name="matrixTable" as="element()">
      <xsl:apply-templates mode="make-matrix-table" select=".">
        <xsl:with-param name="doDebug" as="xs:boolean" tunnel="yes" select="$doDebug"/>
        <xsl:with-param name="colspecElems" as="element()*" select="*[df:class(., 'topic/colspec')]" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:if test="$doDebug">
      <xsl:variable name="matrixTableURI" as="xs:string"
        select="relpath:newFile($outputPath, 'matrixTable.xml')"
      />
      <xsl:message> + [DEBUG] Writing matrix table to <xsl:value-of select="$matrixTableURI"/></xsl:message>
      <xsl:result-document href="{$matrixTableURI}" indent="yes">
        <xsl:sequence select="$matrixTable"/>
      </xsl:result-document>
    </xsl:if>
    <xsl:variable name="numBodyRows"  as="xs:integer"
      select="count($matrixTable/tbody/row)"
    />
    <xsl:variable name="numHeaderRows"  as="xs:integer"
      select="count($matrixTable/thead/row)"
    />
    <xsl:variable name="numCols" select="count($matrixTable/*[1]/*[1]/cell)" as="xs:integer"/>
    <xsl:variable name="tableID" select="generate-id(.)"/>
    <xsl:variable name="tStyle" select="e2s:getTStyleForElement(.)" as="xs:string"/>
    <xsl:if test="$numCols != count(*[df:class(., 'topic/colspec')])">
      <xsl:message> + [WARN] Table <xsl:value-of select="../*[df:class(., 'topic/title')]"/>:</xsl:message>
      <xsl:message> + [WARN]   Maximum column count (<xsl:value-of select="$numCols"/>) not equal to number of colspec elements (<xsl:value-of select="count(*[df:class(., 'colspec')])"/>).</xsl:message>
    </xsl:if>
     <Table 
      AppliedTableStyle="TableStyle/$ID/{$tStyle}" 
      TableDirection="LeftToRightDirection"
      HeaderRowCount="{$numHeaderRows}" 
      FooterRowCount="0" 
      BodyRowCount="{$numBodyRows}" 
      ColumnCount="{$numCols}" 
      Self="rc_{generate-id()}"><xsl:text>&#x0a;</xsl:text>
      <xsl:apply-templates select="." mode="crow">
        <xsl:with-param name="matrixTable" as="element()" tunnel="yes" select="$matrixTable"/>
      </xsl:apply-templates>
       
      <!-- replace this apply templates with function to generate ccol elements.
        This apply-templates generates a ccol for every cell; just need one ccol for each column
        <xsl:apply-templates select="row" mode="ccol"/> -->
      <xsl:sequence 
        select="incxgen:makeColumnElems(
                 *[df:class(., 'topic/colspec')], 
                 $numCols,
                 $tableID)"
      />
      <xsl:apply-templates>
        <xsl:with-param name="colCount" select="$numCols" as="xs:integer" tunnel="yes"/>
        <xsl:with-param name="rowCount" select="$numHeaderRows + $numBodyRows" as="xs:integer" tunnel="yes"/>
        <xsl:with-param name="colspecElems" as="element()*" select="*[df:class(., 'topic/colspec')]" tunnel="yes"/>
      <xsl:with-param name="matrixTable" as="element()" tunnel="yes" select="$matrixTable"/>
      </xsl:apply-templates>
    </Table><xsl:text>&#x0a;</xsl:text>    
  </xsl:template>
  
  <xsl:template match="*[df:class(., 'topic/tgroup')]" mode="crow">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="*[df:class(., 'topic/colspec')]" mode="crow #default">
    <!-- Ignored in this mode -->
  </xsl:template>
  
  <xsl:template 
    match="
    *[df:class(., 'topic/tbody')] |
    *[df:class(., 'topic/thead')]
    " 
    mode="crow #default">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="*[df:class(., 'topic/row')]" mode="crow">
    <xsl:param name="matrixTable" as="element()" tunnel="yes"/>
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    <!-- In InDesign tables, the header and body rows are indexed together
      
      Note that the index is zero indexed.
      -->
    <xsl:variable name="rowid" as="xs:string" select="generate-id(.)"/>
    
    <xsl:variable name="rowIndex"  as="xs:integer"
      select="count(ancestor::*[df:class(., 'topic/tgroup')]//*[df:class(., 'topic/row')][. &lt;&lt; current()] )"/>
    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] crow: topic/row - rowIndex="<xsl:value-of select="$rowIndex"/>"</xsl:message>
    </xsl:if>
    <Row 
      Name="{$rowIndex}" 
      SingleRowHeight="1" 
      Self="{generate-id(..)}crow{$rowIndex}"/><xsl:text>&#x0a;</xsl:text>
  </xsl:template>
  
  <xsl:template match="*[df:class(., 'topic/row')]">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="*[df:class(., 'topic/entry')]">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    <xsl:param name="articleType" as="xs:string" tunnel="yes"/>
    <xsl:param name="cellStyle" as="xs:string" tunnel="yes" select="'[None]'"/>
    <xsl:param name="colCount" as="xs:integer" tunnel="yes"/>
    <xsl:param name="rowCount" as="xs:integer" tunnel="yes"/>
    <xsl:param name="colspecElems" as="element()*" tunnel="yes" />

    <xsl:param name="matrixTable" as="element()" tunnel="yes" />
    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] topic/entry: "<xsl:value-of select="substring(., 80)"/>"</xsl:message>
      <xsl:message> + [DEBUG] topic/entry:     namest: <xsl:value-of select="@namest"/></xsl:message>
      <xsl:message> + [DEBUG] topic/entry:     nameend: <xsl:value-of select="@nameend"/></xsl:message>
    </xsl:if>

    <xsl:variable name="cellid" as="xs:string" select="generate-id(.)"/>
    <xsl:variable name="parentRow" as="element()" select=".."/>
    <xsl:variable name="rowNumber" 
      as="xs:integer"
      select="count(ancestor::*[df:class(., 'topic/tgroup')]//*[df:class(., 'topic/row')][. &lt;&lt; $parentRow] )"
    />
    
    
    <xsl:variable name="colNumber" as="xs:integer"
      select="count($matrixTable//cell[@cellid = $cellid][1]/preceding-sibling::cell)"
      >
    </xsl:variable>
    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] topic/entry:   colNumber="<xsl:value-of select="$colNumber"/>"</xsl:message>
    </xsl:if>
    
    <xsl:variable name="colspan">
      <xsl:choose>
        <xsl:when test="incxgen:isColSpan(.,$colspecElems)">
          <xsl:value-of select="incxgen:numberColsSpanned(.,$colspecElems)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="1"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] topic/entry: colspan="<xsl:value-of select="$colspan"/>"</xsl:message>
    </xsl:if>
    <xsl:variable name="rowspan">
      <xsl:choose>
        <xsl:when test="@morerows">
          <xsl:value-of select="number(@morerows)+1"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="1"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="colSpan" select="incxgen:makeCSpnAttr($colspan,$colCount)"/>
    <xsl:variable name="rowSpan" select="incxgen:makeRSpnAttr($rowspan,$rowCount)"/>
    <xsl:variable name="justification" as="xs:string"
      select="if (@align = 'center') then 'CenterAlign'
                 else if (@align = 'right') then 'RightAlign'
                      else ''"
    />
    <!-- <xsl:message select="concat('[DEBUG: r: ',$colSpan,' c: ',$rowSpan)"/> -->
    <xsl:text> </xsl:text><Cell 
      Name="{$colNumber}:{$rowNumber}" 
      RowSpan="{$rowSpan}" 
      ColumnSpan="{$colSpan}" 
      AppliedCellStyle="CellStyle/$ID/${cellStyle}" 
      ppcs="l_0" 
      Self="rc_{generate-id()}">
      <xsl:if test="@valign">
        <xsl:choose>
          <xsl:when test="@valign = 'bottom'">
            <xsl:attribute name="VerticalJustification" select="'BottomAlign'"/>
          </xsl:when>
          <xsl:when test="@valign='middle'">
            <xsl:attribute name="VerticalJustification" select="'CenterAlign'"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- Top is the default -->
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
      <xsl:text>&#x0a;</xsl:text>
      <!-- must wrap cell contents in txsr and pcnt -->
      <xsl:variable name="pStyle" as="xs:string">
        <xsl:choose>
          <xsl:when test="ancestor::*[df:class(., 'topic/thead')]">
            <xsl:value-of select="'Columnhead'"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="'Body Table Cell'"></xsl:value-of>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:variable name="cStyle" select="'$ID/[No character style]'" as="xs:string"/>
      <xsl:variable name="pStyleObjId" select="incxgen:getObjectIdForParaStyle($pStyle)" as="xs:string"/>
      <xsl:variable name="cStyleObjId" select="incxgen:getObjectIdForCharacterStyle($cStyle)" as="xs:string"/>
      <xsl:choose>
        <xsl:when test="df:hasBlockChildren(.)">
          <!-- FIXME: handle non-empty text before first block element -->
          <xsl:apply-templates>
            <xsl:with-param name="justification" tunnel="yes" select="$justification" as="xs:string"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="makeBlock-cont">
            <xsl:with-param name="pStyle" tunnel="yes" select="e2s:getPStyleForElement(., $articleType)"/>
            <xsl:with-param name="justification" tunnel="yes" select="$justification" as="xs:string"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text> </xsl:text></Cell><xsl:text>&#x0a;</xsl:text>
  </xsl:template>
  
  <xsl:template name="makeTableCaption">
    <xsl:param name="caption" as="node()*"/>
    <xsl:variable name="pStyle" select="'tableCaption'" as="xs:string"/>
    <xsl:variable name="cStyle" select="'$ID/[No character style]'" as="xs:string"/>
    <xsl:variable name="pStyleEscaped" as="xs:string" select="incxgen:escapeStyleName($pStyle)"/>
    <xsl:variable name="cStyleEscaped" as="xs:string" select="incxgen:escapeStyleName($cStyle)"/>
    
    <ParagraphStyleRange
      AppliedParagraphStyle="ParagraphStyle/{$pStyleEscaped}"><xsl:text>&#x0a;</xsl:text>
      <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/{$cStyleEscaped}" ParagraphBreakType="NextFrame"
        ><xsl:value-of select="$caption"/></CharacterStyleRange><xsl:text>&#x0a;</xsl:text>
    </ParagraphStyleRange><xsl:text>&#x0a;</xsl:text>  
  </xsl:template>
  
  <xsl:template match="text()" mode="calcRowEntryCounts"/>
  
  <xsl:template mode="crow" match="*" priority="-1">
    <xsl:message> + [WARNING] (crow mode): Unhandled element <xsl:sequence select="name(..)"/>/<xsl:sequence 
      select="concat(name(.), ' [', normalize-space(@class), ']')"/></xsl:message>
  </xsl:template>
  
  <!-- =======================
       Mode make matrix table
       
       Construct a table where every 
       cell of the table is explicit
       so that it's easy to account
       for vertical and horizontal
       spans when calculating the
       effective column number of 
       cells.       
       ======================= -->
  
  <xsl:template 
    match="
    *[df:class(., 'topic/tgroup')]
    " 
    mode="make-matrix-table">
   <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
   
   <xsl:if test="$doDebug">
     <xsl:message> + [DEBUG] make-matrix-table: <xsl:value-of select="name(.)"/>...</xsl:message>
   </xsl:if>
   <!-- Construct a table of rows and columns
        reflecting each logical row and column
        of the table so that we know, for any
        cell, know what it's absolute row/column
        position within the matrix is.     
     
       Do this in two phases:
     
        1. Generate a set of cells, each labeled with the 
           original row it was generated from and labeled
           with its absolute row and column number.
           
        2. Group the cells by row to create the set of 
           absolute rows and cells, over which spans
           are overlayed.
           
     -->
   <xsl:if test="$doDebug">
     <xsl:message> + [DEBUG] make-matrix-table: Constructing cell set...</xsl:message>
   </xsl:if>
   
   <xsl:variable name="cellSet" as="element()*" 
     >
     <!-- Apply templates to the first row in the first child of tgroup,
          either thead or tbody.
          
          Basic approach is to process each row, accumulating cells.
          We pass the accumulated cells to the next row so that we know
          if there are any cells intruding into the following row (because
          they will already have the same row number and a column number)
       -->
     <xsl:apply-templates 
       mode="make-cell-set"
       select="*[df:class(., 'topic/thead') or df:class(., 'topic/tbody')][1]/*[1]" 
       >
        <xsl:with-param name="doDebug" as="xs:boolean" tunnel="yes" select="$doDebug"/>
       <xsl:with-param name="rowCount" as="xs:integer" select="0"/>
       <xsl:with-param name="cellSet" as="element()*" tunnel="yes" select="()"/>
     </xsl:apply-templates>
   </xsl:variable>

    <xsl:if test="$doDebug">
      <xsl:variable name="cellSetURI" as="xs:string"
        select="relpath:newFile($outputPath, 'cellSet.xml')"
      />
      <xsl:message> + [DEBUG] Writing cell set to <xsl:value-of select="$cellSetURI"/></xsl:message>
      <xsl:result-document href="{$cellSetURI}" indent="yes">
        <cellSet>
          <xsl:sequence select="$cellSet"/>
        </cellSet>
      </xsl:result-document>
    </xsl:if>

   <xsl:if test="$doDebug">
     <xsl:message> + [DEBUG] make-matrix-table: Constructing matrix table...</xsl:message>
   </xsl:if>
   <xsl:variable name="matrixTable" as="element()">
     <matrixTable>
       <xsl:for-each-group select="$cellSet" group-by="@tableZone">
         <xsl:element name="{current()/@tableZone}">
           <xsl:for-each-group select="current-group()" group-by="@rownum">
             <row rowid="{current()/@rowid}" tableZone="{current()/@tableZone}">
               <xsl:sequence select="current-group()"/>
             </row>               
           </xsl:for-each-group>
         </xsl:element>
       </xsl:for-each-group>
     </matrixTable>
   </xsl:variable>
   <xsl:sequence select="$matrixTable"/>
  </xsl:template>
  <xsl:template mode="make-cell-set" match="*[df:class(., 'topic/entry')]">
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    <xsl:param name="colspecElems" as="element()*" tunnel="yes" />
    <xsl:param name="cellSet" as="element()*" tunnel="yes"/><!-- All cells created up to this point. -->
    
    <xsl:variable name="tableZone" as="xs:string" 
      select="name(../..)"
    />
    
    <!-- Number of preceding rows -->
    <xsl:variable name="parentRow" as="element()" select=".."/>
    <xsl:variable name="rowCount" as="xs:integer"
      select="count(ancestor::*[df:class(., 'topic/tgroup')]//*[df:class(., 'topic/row')][. &lt;&lt; $parentRow] )"
    />

    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] make-cell-set: topic/entry - $rowCount=<xsl:value-of select="$rowCount"/></xsl:message>
    </xsl:if>    
    
    <xsl:variable name="entryElem" as="element()" select="."/>
    <xsl:variable name="rowid" as="xs:string" select="generate-id(..)"/>
    <xsl:variable name="numColsSpanned" as="xs:integer" 
            select="incxgen:numberColsSpanned(.,$colspecElems)"
    />
    <xsl:variable name="moreRows" as="xs:integer" select="(@morerows, 0)[1]"/>
    <xsl:variable name="numRowsSpanned" as="xs:integer"
      select="$moreRows + 1"
    />
    <xsl:for-each select="1 to $numRowsSpanned">
      <xsl:variable name="rownum" as="xs:integer" select="."/>
      <xsl:for-each select="1 to $numColsSpanned">
        <cell rowid="{$rowid}" 
          cellid="{generate-id($entryElem)}" 
          rownum="{$rowCount + $rownum}"
          tableZone="{$tableZone}"
          >
          <xsl:value-of select="substring($entryElem, 1, 40)"/>
        </cell>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template mode="make-cell-set" match="*[df:class(., 'topic/row')]">
    <!-- This is recursive template, in that each row applies this template
         to its next sibling. Note that if the parent is the thead,
         needs to apply to the first child of the following tbody.
      -->
    <xsl:param name="doDebug" as="xs:boolean" tunnel="yes" select="false()"/>
    <xsl:param name="rowCount" as="xs:integer"/>
    <xsl:apply-templates select="*" mode="#current">
      <xsl:with-param name="rowCount" as="xs:integer" select="$rowCount"/>
    </xsl:apply-templates>
    <xsl:variable name="moreRows" as="xs:integer"
      select="if (*/@morerows) then max(for $att in */@morerows return xs:integer($att)) else 0"
    />
    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] make-cell-set: moreRows="<xsl:value-of select="$moreRows"/>"</xsl:message>
    </xsl:if>
    <xsl:variable name="rowsConsumed" as="xs:integer"
      select="1 + $moreRows"
    />
    <xsl:if test="$doDebug">
      <xsl:message> + [DEBUG] make-cell-set: rowsConsumed="<xsl:value-of select="$rowsConsumed"/>"</xsl:message>
    </xsl:if>
    <xsl:apply-templates mode="#current"
      select="
      if (../self::*[df:class(., 'topic/thead')]) 
         then (following-sibling::*[df:class(., 'topic/row')][1], 
               ../../*[df:class(., 'topic/tbody')]/*[df:class(., 'topic/row')][1])[1]
         else following-sibling::*[df:class(., 'topic/row')][1]"
      >
      <xsl:with-param name="doDebug" tunnel="yes" as="xs:boolean" select="$doDebug"/>
      <xsl:with-param name="rowCount" as="xs:integer" select="$rowCount + $rowsConsumed"/>
    </xsl:apply-templates>
  </xsl:template>
  <xsl:template mode="make-cell-set make-matrix-table" match="*" priority="-1">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <!-- ======= End of make-matrix-table ============ -->
  <!-- This template returns values that must be added to the table matrix. Every cell in the box determined
     by start-row, end-row, start-col, and end-col will be added. First add every value from the first
     column. When past $end-row, move to the next column. When past $end-col, every value is added. -->
  <xsl:template name="add-to-matrix">
    <xsl:param name="start-row" as="xs:integer"/>       
    <xsl:param name="end-row" as="xs:integer"/>
    <xsl:param name="current-row" select="$start-row" as="xs:integer"/>
    <xsl:param name="start-col" as="xs:integer"/>
    <xsl:param name="end-col" as="xs:integer"/>
    <xsl:param name="current-col" select="$start-col" as="xs:integer"/>
    <xsl:choose>
      <xsl:when test="$current-col > $end-col"/>   <!-- Out of the box; every value has been added -->
      <xsl:when test="$current-row > $end-row">    <!-- Finished with this column; move to next -->
        <xsl:call-template name="add-to-matrix">
          <xsl:with-param name="start-row"  select="$start-row" as="xs:integer"/>
          <xsl:with-param name="end-row" select="$end-row" as="xs:integer"/>
          <xsl:with-param name="current-row" select="$start-row" as="xs:integer"/>
          <xsl:with-param name="start-col" select="$start-col" as="xs:integer"/>
          <xsl:with-param name="end-col" select="$end-col" as="xs:integer"/>
          <xsl:with-param name="current-col" select="$current-col + 1" as="xs:integer"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <!-- Output the value for the current entry -->
        <xsl:sequence select="concat('[', $current-row, ':', $current-col, ']')"/>
        <!-- Move to the next row, in the same column. -->
        <xsl:call-template name="add-to-matrix">
          <xsl:with-param name="start-row" select="$start-row" as="xs:integer"/>
          <xsl:with-param name="end-row" select="$end-row" as="xs:integer"/>
          <xsl:with-param name="current-row" select="$current-row + 1" as="xs:integer"/>
          <xsl:with-param name="start-col" select="$start-col" as="xs:integer"/>
          <xsl:with-param name="end-col" select="$end-col" as="xs:integer"/>
          <xsl:with-param name="current-col" select="$current-col" as="xs:integer"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="incxgen:isColSpan" as="xs:boolean">
    <xsl:param name="elem" as="element()"/>
    <xsl:param name="colspecElems" as="element()*"/>
    <xsl:variable name="namest" select="if ($elem/@namest) then $elem/@namest else ''" as="xs:string" />
    <xsl:variable name="nameend" select="if ($elem/@nameend) then $elem/@nameend else ''" as="xs:string" />
    <xsl:variable name="isColSpan" select="
      if ($namest ne '' and $nameend ne '') then
      (if ($namest ne $nameend) then 
      (if ($colspecElems[@colname=$namest] and $colspecElems[@colname=$nameend]) then true()
      else false())
      else false ())
      else false ()"
      as="xs:boolean" />
    <xsl:sequence select="$isColSpan"/>
  </xsl:function>
  
  <xsl:function name="incxgen:numberColsSpanned" as="xs:integer">
    <xsl:param name="elem" as="element()"/>
    <xsl:param name="colspecElems" as="element()*"/>
    <xsl:variable name="namest" select="if ($elem/@namest) then $elem/@namest else ''" as="xs:string" />
    <xsl:variable name="nameend" select="if ($elem/@nameend) then $elem/@nameend else ''" as="xs:string" />
    <xsl:variable name="numColsBeforeStartColSpan" select="count($colspecElems[@colname=$namest]/preceding::*[self::colspec or df:class(.,'topic/colspec')])" as="xs:integer" />
    <xsl:variable name="numColsBeforeEndColSpan" select="count($colspecElems[@colname=$nameend]/preceding::*[self::colspec or df:class(.,'topic/colspec')])" as="xs:integer" />
    <xsl:sequence select="$numColsBeforeEndColSpan - $numColsBeforeStartColSpan + 1"/>    
  </xsl:function>
  
  
  
  
</xsl:stylesheet>
