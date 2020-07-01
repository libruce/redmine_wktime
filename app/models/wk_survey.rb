class WkSurvey < ActiveRecord::Base
    
	belongs_to :group , :class_name => 'Group'
  belongs_to :survey_for, :polymorphic => true
  has_many :wk_survey_questions, foreign_key: "survey_id", class_name: "WkSurveyQuestion", :dependent => :destroy
  has_many :wk_survey_choices, through: :wk_survey_questions
  has_many :wk_survey_responses, foreign_key: "survey_id", :dependent => :destroy
  has_many :wk_survey_answers, through: :wk_survey_responses

  accepts_nested_attributes_for :wk_survey_questions, allow_destroy: true

  validates_presence_of :name

  scope :surveyTextQuestion, ->(survey_id){
      joins(:wk_survey_questions)
      .where("wk_surveys.id = #{survey_id} AND wk_survey_questions.question_type IN ('TB', 'MTB') AND 
          wk_survey_questions.not_in_report IS FALSE ")
      .select("wk_surveys.id, wk_surveys.name, wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name")
      .order("wk_surveys.id, wk_survey_questions.id")
  }

  scope :getTextAnswer, ->(survey_id, surveyForType){
    surveyTextQuestion(survey_id).joins(:wk_survey_answers)
    .where(" wk_survey_questions.id = wk_survey_answers.survey_question_id AND 
      wk_survey_responses.survey_for_type " + (surveyForType.blank? ? " IS NULL " : " = '#{surveyForType}'"))
    .select("wk_survey_answers.choice_text")
  }

  scope :responsedTextAnswer, ->(groupName){
    where("wk_survey_responses.group_name = '#{groupName}'")
    .order("wk_survey_answers.survey_response_id")
  }

  scope :currentRespTxtAnswer, -> { where("wk_survey_responses.group_name IS NULL")
    .order("wk_survey_answers.survey_response_id") 
  }

  def getGroupName
    survey_response = self.wk_survey_responses.where("wk_survey_responses.user_id =  ? ", User.current.id)
      .order("wk_survey_responses.updated_at").last
    group_name = survey_response.try(:group_name)
  end

  scope :surveyAvgQuestion, ->(survey_id, question_id, castFormat){
    joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id
      INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id
      INNER JOIN wk_survey_responses ON wk_surveys.id = wk_survey_responses.survey_id
      INNER JOIN wk_survey_answers ON wk_survey_responses.id = wk_survey_answers.survey_response_id AND wk_survey_questions.id = wk_survey_answers.survey_question_id AND wk_survey_choices.id = wk_survey_answers.survey_choice_id")
    .where("wk_surveys.id = #{survey_id} and wk_survey_questions.id = #{question_id} ")
    .select("SUM(CAST(wk_survey_choices.name AS #{castFormat}))/count(wk_survey_responses.user_id) AS questionavg, wk_survey_questions.id AS question_id, wk_surveys.id AS survey_id, CASE WHEN wk_survey_responses.group_name IS NULL THEN 'Current' ELSE wk_survey_responses.group_name END AS grpname")
    .group("wk_surveys.id, wk_survey_questions.id, wk_survey_responses.group_date, wk_survey_responses.group_name")
  }

  scope :getSurveyChoices, ->(survey_id){ joins(:wk_survey_questions, :wk_survey_choices)
    .where("wk_surveys.id = #{survey_id}")
    .select("wk_survey_choices.name")
    .group("wk_survey_choices.name")
  }
end