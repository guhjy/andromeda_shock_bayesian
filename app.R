# ANDROMDA-SHOCK Bayesian Re-Analysis
# Adapted from code by Dan Lane

library(shiny)
library(tidyverse)

ui <- bootstrapPage(
  shinyUI(
    navbarPage("ANDROMEDA-SHOCK Bayesian Re-Analysis", 
               id = "tabs",
    tabPanel("Distributions",
             fluidPage(
               tags$style(HTML(".irs-bar {width: 100%; height: 5px; background: black; border-top: 1px solid black; border-bottom: 1px solid black;}")),
               tags$style(HTML(".irs-bar-edge {background: black; border: 1px solid black; height: 5px; border-radius: 15px 15px 15px 15px;}")),
               tags$style(HTML(".irs-line {border: 1px solid black; height: 5px;}")),
               tags$style(HTML(".irs-grid-text {font-family: 'arial'; color: black}")),
               tags$style(HTML(".irs-max {font-family: 'arial'; color: black;}")),
               tags$style(HTML(".irs-min {font-family: 'arial'; color: black;}")),
               tags$style(HTML(".irs-single {color:white; background:black;}")), 
               sidebarPanel(
                 sliderInput("theta",
                             "Prior Mean:",
                             min = 0.5,
                             max = 1.25,
                             value = 1,
                             step = 0.01,
                             ticks = FALSE),
                 hr(),
                 sliderInput("hr",
                             "Cutoff for HR for computing the width of the prior distribution (e.g., MCID):",
                             min = 0.25,
                             max = 1.25,
                             value = 0.5,
                             step = 0.01,
                             ticks = FALSE),
                 sliderInput("pr",
                             "Probability that the HR is less than this cutoff:",
                             min = 0,
                             max = 1,
                             value = 0.05,
                             step = 0.01,
                             ticks = FALSE),
                 hr(),
                 sliderInput("sd",
                             "Prior SD:",
                             min = 0.1,
                             max = 1,
                             value = 0.42,
                             step = 0.01,
                             ticks = FALSE),
                 hr(),
                 sliderInput("ci",
                             "Posterior Credible Interval: ",
                             value = 89,
                             min = 60,
                             max = 99,
                             step = 1,
                             post = "%",
                             ticks = FALSE),
                 sliderInput("hr_post",
                             "Posterior HR of Interest: ",
                             min = 0.5,
                             max = 1.25,
                             value = 0.9,
                             step = 0.01,
                             ticks = FALSE)
                 
                 ),
               
               # Show a plot of the generated distributions
               mainPanel(plotOutput("distPlot")
                         ),
               
               fluidRow(column(12,
                        hr(),
                        h4("About this Application:"),
                        uiOutput("link_twitter"),
                        br(),
                        uiOutput("link_paper"),
                        uiOutput("link_discourse"),
                        uiOutput("link_email"),
                        br(),
                        renderText(expr = output$paper_link)
                        )
                        )
               )
             ),
    
    tabPanel("Heat Map",
             fluidPage(
               fluidRow(column(12,
                               h4("Interactive Heat Map:"),
                               uiOutput("heat_text"),
                               hr()
                               ),
               sidebarPanel(
                 sliderInput("hr_heat",
                             "Posterior HR of Interest:",
                             min = 0.5,
                             max = 1.25,
                             value = 0.9,
                             step = 0.01,
                             ticks = FALSE)
               ),
               mainPanel(
                 plotOutput("heatPlot")
                 )
               )
               )
               )
             )
    )
)

server <- function(input, output, session) {
   
  # Calculating MCID using the estimated reductions from the power calculation 
  
  a <- 0.3 * 420 # Intervention and Outcome
  b <- 0.45 * 420 # Control and Outcome
  c <- 420 - a # Intervention No Outcome
  d <- 420 - b # Control No Outcome
  
  MCID <- ((a+0.5) * (d+0.5))/((b+0.5) * (c+0.5))
  
  # Publication Data
  HR <- 0.75
  UC <- 1.02
  
  # Calculate Priors
  theta_in <- reactive({input$theta})
  sd_in <- reactive({input$sd})
  hr_in <- reactive({input$hr})
  pr_in <- reactive({input$pr})
  
  # Update sliders based on SD and Pr and HR
  observeEvent(input$sd, {
    updateSliderInput(session,
                      inputId = "pr",
                      label = "Probability that the HR is less than this cutoff:",
                      value = round(pnorm(log(hr_in()), log(theta_in()), sd_in()), 3)
    )
  })
  
  observeEvent(input$hr, {
    updateSliderInput(session,
                      inputId = "pr",
                      label = "Probability that the HR is less than this cutoff:",
                      value = round(pnorm(log(hr_in()), log(theta_in()), sd_in()), 3),
                      min = round(pnorm(log(hr_in()), log(theta_in()), 0.1), 3),
                      max = round(pnorm(log(hr_in()), log(theta_in()), 1), 3)
                      )

  })
  
  observeEvent(input$theta, {
    updateSliderInput(session,
                      inputId = "pr",
                      label = "Probability that the HR is less than this cutoff:",
                      value = round(pnorm(log(hr_in()), log(theta_in()), sd_in()), 3),
                      min = round(pnorm(log(hr_in()), log(theta_in()), 0.1), 3),
                      max = round(pnorm(log(hr_in()), log(theta_in()), 1), 3)
                      )
  })
  
  observeEvent(input$pr, {
    updateSliderInput(session,
                      inputId = "sd",
                      label = "Prior SD:",
                      value = round((log(hr_in()) - log(theta_in()))/qnorm(pr_in()), 3)
    )
  })
  
  prior_theta <- reactive({log(theta_in())})
  prior_sd <- reactive({sd_in()})
  
  # Calculate Likelihood Parameters
  likelihood_theta <- log(HR)
  likelihood_sd <- (log(UC) - log(HR)) / qnorm(0.975) # SD from 95% CI in trial
  
  # Calculate Posterior Parameters
  post_theta <- reactive({
    ((prior_theta() / (prior_sd())^2)+(likelihood_theta / likelihood_sd^2)) / 
      ((1 / (prior_sd())^2) + (1 / likelihood_sd^2))
    })
  post_sd <- reactive({
    sqrt(1 / ((1 / (prior_sd())^2) + (1 / likelihood_sd^2)))
    })
  
  # Plot data
  x <- seq(-3, 3, by = 0.01)
  prior_plot <- reactive({dnorm(x, prior_theta(), prior_sd())})
  likelihood_plot <- dnorm(x, likelihood_theta, likelihood_sd)
  posterior_plot <- reactive({dnorm(x, post_theta(), post_sd())})
  
  plot_data <- reactive({
    tibble(
      x = rep(x, 3)
    ) %>%
      mutate(
        dist = rep(c("prior", "likelihood", "posterior"), each = nrow(.) / 3),
        y = c(prior_plot(), likelihood_plot, posterior_plot()),
        x = exp(x),
        y = exp(y)
      )
      
  })
  
  # Credible interval
  ci_in <- reactive({input$ci})
  
  # HR Post
  hr_post <- reactive({input$hr_post})
  
  # Dynamic Plot
   output$distPlot <- renderPlot({
     plot_data() %>%
       ggplot(aes(x = x, y = y, group = dist)) + 
       geom_vline(xintercept = 1, linetype = "dashed",
                  color = "grey50", alpha = 0.75) + 
       geom_line(aes(color = dist),
                 size = 1.1) + 
       scale_color_brewer(name = NULL, type = "qual", palette = "Dark2",
                          breaks = c("prior", "likelihood", "posterior"),
                          labels = c("Prior", "Likelihood", "Posterior")) + 
       xlim(0, 2) + 
       labs(
         x = "Hazard Ratio",
         y = "Probability Density"
       ) + 
       annotate(geom = "text",
                label = paste("Posterior probability HR < 1: ", 
                              round(pnorm(log(1), post_theta(), post_sd(), 
                                          lower.tail = TRUE), 3), sep = ""),
                x = 2, y = max(plot_data()$y), hjust = 1,
                fontface = "bold") + 
       annotate(geom = "text",
                label = paste("Posterior probability HR < ", hr_post(),
                              paste(": ", round(pnorm(log(hr_post()), post_theta(), post_sd(),
                                                          lower.tail = TRUE), 3), sep = ""), sep = ""),
                x = 2, y = max(plot_data()$y) - max(plot_data()$y/25), hjust = 1,
                fontface = "bold") + 
       annotate(geom = "text",
                label = paste("Posterior median (", ci_in(),
                              paste("% credible interval): ",
                                    round(exp(qnorm(0.5, post_theta(), post_sd())), 2),
                                    paste(" (", round(exp(qnorm((1 - (ci_in()/100)) / 2, post_theta(), post_sd())), 2), sep = ""),
                              paste(", ", round(exp(qnorm(1 - (1 - (ci_in()/100)) / 2, post_theta(), post_sd())), 2), sep = ""),
                              paste(")", sep = ""), sep = ""), sep = ""),
                x = 2, y = max(plot_data()$y) - (2 * max(plot_data()$y)/25), hjust = 1,
                fontface = "bold") + 
       theme_classic() + 
       theme(
         legend.position = "bottom",
         text = element_text(family = "Gill Sans MT"),
         axis.ticks.y = element_blank(),
         axis.text.y = element_blank(),
         axis.title = element_text(size = 15),
         axis.text = element_text(size = 12),
         legend.text = element_text(size = 15)
       )
   }, height = 620)
   
   # HR Heat
   hr_heat <- reactive({input$hr_heat})
   
   # Heat data
   theta_list <- seq(from = 0.5, to = 1.5, by = 0.01)
   sd_list <- seq(from = 0.1, to = 0.8, length = length(theta_list))
   
    heat_data <- reactive({
     tibble(
       prior_theta = rep(theta_list, each = length(theta_list)),
       prior_sd = rep(sd_list, times = length(sd_list))
     ) %>%
     mutate(
       post_theta = ((log(prior_theta) / (prior_sd)^2)+(likelihood_theta / likelihood_sd^2)) / 
         ((1 / (prior_sd)^2)+(1 / likelihood_sd^2)),
       post_sd = sqrt(1 / ((1 / (prior_sd)^2) + (1 / likelihood_sd^2))),
       p_hr = pnorm(log(hr_heat()), post_theta, post_sd, lower.tail = TRUE)
     )
    })
  
   # Dynamic Heat Plot
   output$heatPlot <- renderPlot({
     heat_data() %>%
       ggplot(aes(x = prior_theta, y = prior_sd)) + 
       geom_tile(aes(fill = p_hr)) + 
       scale_fill_viridis_c(name = paste("Posterior Probabilty HR < ", hr_heat(), sep = ""),
                            begin = min(heat_data()$p_hr),
                            end = max(heat_data()$p_hr)) + 
       labs(
         x = "Prior Mean",
         y = "Prior SD"
       ) + 
       theme_classic() + 
       theme(
         text = element_text(family = "Gill Sans MT"),
         axis.title = element_text(size = 15),
         axis.text = element_text(size = 12),
         legend.text = element_text(size = 12),
         legend.title = element_text(size = 14),
         legend.position = "right"
       )
   }, width = 750, height = 550)
   
   # Link for paper
   url_paper <- a("JAMA", 
                  href="https://jamanetwork.com/journals/jama/fullarticle/2724361")
   url_discourse <- a("DataMethods", 
                      href="https://discourse.datamethods.org/t/andromeda-shock-or-how-to-intepret-hr-0-76-95-ci-0-55-1-02-p-0-06/1349")
   url_email <- a("benjamin.andrew@duke.edu", 
                  href="mailto:benjamin.andrew@duke.edu")
   url_bat <- a("(@BenYAndrew).", 
                href="https://twitter.com/BenYAndrew")
   url_dlt <- a("(@DanLane911)", 
                href="https://twitter.com/DanLane911")
   
    output$link_paper <- renderUI({
     tagList("Original paper: ", url_paper)
   })
   output$link_discourse <- renderUI({
     tagList("Discussion: ", url_discourse)
   })
   output$link_email <- renderUI({
     tagList("Questions & Improvements: ", url_email)
   })
   output$link_twitter <- renderUI({
     tagList("This is an interactive Bayesian re-analysis of the ANDROMEDA-SHOCK trial published in JAMA. Code by Dan Lane", url_dlt, "and adapted by Ben Andrew", url_bat, "Update the prior distribution using the sliders above by either (1) setting the prior SD directly or (2) setting a HR threshold and probability mass of the prior to lie below that threshold.") 
   })
   output$heat_text <- renderUI({
     tagList("Use the slider below to select a posterior HR of interest. The heat map will display the posterior probability of HR < your selected value for all combinations of the prior's mean and SD.") 
   })

}
# Run the application 
shinyApp(ui = ui, server = server)
