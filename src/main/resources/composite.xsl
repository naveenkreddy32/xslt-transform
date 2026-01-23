<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" />

  <!-- Main template that accepts the composite payload -->
  <xsl:template match="/">
    <!-- Store the two input documents as variables -->
    <xsl:variable name="routeResp" select="root/routeResp/*" />
    <xsl:variable name="stopConfirmReq" select="root/stopConfirmReq/*" />

    <!-- Validate and transform -->
    <xsl:choose>
      <xsl:when test="not($routeResp) or not($stopConfirmReq)">
        <error>
          <message>Missing input: Both routeResp and stopConfirmReq are required</message>
        </error>
      </xsl:when>
      <xsl:otherwise>
        <!-- Perform validation and transformation -->
        <xsl:apply-templates select="$stopConfirmReq" mode="validate-and-transform">
          <xsl:with-param name="routeResp" select="$routeResp" />
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Main transformation template -->
  <xsl:template match="StandardWincantonTMSStopConfirmationRequest" mode="validate-and-transform">
    <xsl:param name="routeResp" />

    <!-- Get the stop number from confirmation -->
    <xsl:variable name="stopNumber" select="stop/stopNumber" />
    
    <!-- Store confirmation orders in variable for reference inside loops -->
    <xsl:variable name="confirmOrders" select="stop/orders/order" />

    <!-- Get corresponding stop from route response -->
    <xsl:variable name="routeStop" select="$routeResp/Route/Stops/Stop[StopNumber = $stopNumber]" />

    <!-- Validate stop exists in route -->
    <xsl:choose>
      <xsl:when test="not($routeStop)">
        <error>
          <message>Stop <xsl:value-of select="$stopNumber" /> not found in route response</message>
        </error>
      </xsl:when>
      <xsl:otherwise>
        <!-- Perform validation -->
        <xsl:variable name="validationErrors">
          <xsl:call-template name="validate-orders">
            <xsl:with-param name="confirmOrders" select="$confirmOrders" />
            <xsl:with-param name="routeOrders" select="$routeStop/Orders/Order" />
          </xsl:call-template>
        </xsl:variable>

        <xsl:choose>
          <xsl:when test="$validationErrors/error">
            <!-- Output validation errors wrapped in root tag -->
            <ValidationResult>
              <xsl:copy-of select="$validationErrors/error" />
            </ValidationResult>
          </xsl:when>
          <xsl:otherwise>
            <!-- Build validated output: copy all fields as-is but reorder orders and orderLines -->
            <StandardWincantonTMSStopConfirmationRequest>
              <!-- Copy routeNumber and routeDate as-is -->
              <xsl:copy-of select="routeNumber" copy-namespaces="no" />
              <xsl:copy-of select="routeDate" copy-namespaces="no" />
              
              <stop>
                <!-- Copy stop-level fields as-is (stopNumber, status, arriveTime, completionTime) -->
                <xsl:copy-of select="stop/stopNumber" copy-namespaces="no" />
                <xsl:copy-of select="stop/status" copy-namespaces="no" />
                <xsl:copy-of select="stop/arriveTime" copy-namespaces="no" />
                <xsl:copy-of select="stop/completionTime" copy-namespaces="no" />
                
                <!-- Reorder orders based on route response -->
                <orders>
                  <xsl:for-each select="$routeStop/Orders/Order">
                    <xsl:variable name="routeOrderNum" select="OrderNumber" />
                    <xsl:variable name="confirmOrder" select="$confirmOrders[orderNumber = $routeOrderNum]" />
                    <xsl:variable name="routeOrder" select="." />

                    <order>
                      <!-- Copy order-level fields from confirmation as-is, EXCEPT orderLines -->
                      <xsl:copy-of select="$confirmOrder/orderNumber" copy-namespaces="no" />
                      <xsl:copy-of select="$confirmOrder/jobType" copy-namespaces="no" />
                      <xsl:copy-of select="$confirmOrder/status" copy-namespaces="no" />
                      
                      <!-- Reorder orderLines based on route response, but keep order line data as-is -->
                      <orderLines>
                        <xsl:for-each select="$routeOrder/OrderLines/OrderLine">
                          <xsl:variable name="routeLineId" select="OrderLineID" />
                          <xsl:variable name="routeLineQuantity" select="Quantity" />
                          <xsl:variable name="confirmLine" select="$confirmOrder/orderLines/orderLine[orderLineID = $routeLineId and quantity = $routeLineQuantity]" />
                          
                          <!-- Copy entire orderLine from confirmation as-is -->
                          <xsl:copy-of select="$confirmLine" copy-namespaces="no" />
                        </xsl:for-each>
                      </orderLines>
                      
                      <!-- Copy optional order-level fields if they exist -->
                      <xsl:copy-of select="$confirmOrder/photos" copy-namespaces="no" />
                      <xsl:copy-of select="$confirmOrder/signatures" copy-namespaces="no" />
                    </order>
                  </xsl:for-each>
                </orders>
                
                <!-- Copy optional stop-level fields if they exist -->
                <xsl:copy-of select="stop/photos" copy-namespaces="no" />
                <xsl:copy-of select="stop/signatures" copy-namespaces="no" />
              </stop>
            </StandardWincantonTMSStopConfirmationRequest>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Validation template for orders -->
  <xsl:template name="validate-orders">
    <xsl:param name="confirmOrders" />
    <xsl:param name="routeOrders" />

    <!-- Check for missing orders in confirmation -->
    <xsl:for-each select="$routeOrders">
      <xsl:variable name="routeOrderNum" select="OrderNumber" />
      <xsl:if test="not($confirmOrders[orderNumber = $routeOrderNum])">
        <error>
          <message>Order <xsl:value-of select="$routeOrderNum" /> missing in stop confirmation</message>
        </error>
      </xsl:if>
    </xsl:for-each>

    <!-- Check for additional orders in confirmation -->
    <xsl:for-each select="$confirmOrders">
      <xsl:variable name="confirmOrderNum" select="orderNumber" />
      <xsl:if test="not($routeOrders[OrderNumber = $confirmOrderNum])">
        <error>
          <message>Order <xsl:value-of select="$confirmOrderNum" /> in confirmation but not in route</message>
        </error>
      </xsl:if>
    </xsl:for-each>

    <!-- Validate each order's job type and order lines -->
    <xsl:for-each select="$routeOrders">
      <xsl:variable name="routeOrderNum" select="OrderNumber" />
      <xsl:variable name="routeJobType" select="JobType" />
      <xsl:variable name="confirmOrder" select="$confirmOrders[orderNumber = $routeOrderNum]" />

      <!-- Check job type matches -->
      <xsl:if test="$confirmOrder/jobType != $routeJobType">
        <error>
          <message>Order <xsl:value-of select="$routeOrderNum" />: jobType mismatch. Expected '<xsl:value-of select="$routeJobType" />', got '<xsl:value-of select="$confirmOrder/jobType" />'</message>
        </error>
      </xsl:if>

      <!-- Check for missing order lines in confirmation -->
      <xsl:for-each select="OrderLines/OrderLine">
        <xsl:variable name="routeLineId" select="OrderLineID" />
        <xsl:if test="not($confirmOrder/orderLines/orderLine[orderLineID = $routeLineId])">
          <error>
            <message>Order <xsl:value-of select="$routeOrderNum" />: OrderLine <xsl:value-of select="$routeLineId" /> missing in confirmation</message>
          </error>
        </xsl:if>
      </xsl:for-each>

      <!-- Check for additional order lines in confirmation -->
      <xsl:for-each select="$confirmOrder/orderLines/orderLine">
        <xsl:variable name="confirmLineId" select="orderLineID" />
        <xsl:if test="not($routeOrders[OrderNumber = $routeOrderNum]/OrderLines/OrderLine[OrderLineID = $confirmLineId])">
          <error>
            <message>Order <xsl:value-of select="$routeOrderNum" />: OrderLine <xsl:value-of select="$confirmLineId" /> in confirmation but not in route</message>
          </error>
        </xsl:if>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
